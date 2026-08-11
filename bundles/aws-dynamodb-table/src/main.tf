data "aws_caller_identity" "current" {}

# DynamoDB table names are unique per account and region, so two environments in
# the same account would collide on a plain name like "orders". The suffix keeps
# the name stable for the life of a deployment and changes only if the operator
# renames the table or moves it to another region.
resource "random_id" "suffix" {
  byte_length = 4

  keepers = {
    table_name = var.table_name
    region     = var.region
  }
}

locals {
  table_name = "${var.table_name}-${random_id.suffix.hex}"
  stem       = substr(var.md_metadata.name_prefix, 0, 24)

  # An empty string from the form means "this table has no sort key" and "nothing
  # expires on its own". Terraform needs those absent rather than blank, so they
  # become null here and drive the dynamic blocks below.
  sort_key      = var.sort_key == "" ? null : var.sort_key
  ttl_attribute = var.ttl_attribute == "" ? null : var.ttl_attribute
}

################################################################################
# Encryption key
#
# DynamoDB always encrypts at rest, but the default key is owned by AWS and
# cannot be audited, rotated on demand, or revoked. A key in this account can be.
################################################################################

resource "aws_kms_key" "main" {
  description             = "Encrypts items in ${local.table_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Delegates authorization to IAM, which is what lets the consumer
        # policies below grant use of this key.
        Sid       = "EnableAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "main" {
  name_prefix   = "alias/${local.stem}-table-"
  target_key_id = aws_kms_key.main.key_id
}

################################################################################
# Table
################################################################################

resource "aws_dynamodb_table" "main" {
  name = local.table_name

  # On-demand billing: no capacity to size, no autoscaling to tune, and nothing
  # to pay for a table that sits idle overnight.
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = var.partition_key
  range_key = local.sort_key

  # Only key attributes are declared. Everything else about an item is schemaless
  # and written by the application without any change here.
  attribute {
    name = var.partition_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = local.sort_key == null ? [] : [local.sort_key]

    content {
      name = attribute.value
      type = "S"
    }
  }

  # Rolling 35-day restore window. Restores land in a new table, so this protects
  # against bad writes rather than replacing a delete-protection setting.
  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.main.arn
  }

  # DynamoDB deletes expired items in the background at no cost, usually within a
  # couple of days of the timestamp. Readers can still see an expired item during
  # that window, so applications that must not serve stale data should also filter
  # on the attribute.
  dynamic "ttl" {
    for_each = local.ttl_attribute == null ? [] : [local.ttl_attribute]

    content {
      enabled        = true
      attribute_name = ttl.value
    }
  }

  deletion_protection_enabled = var.deletion_protection

  tags = {
    Name = local.table_name
  }
}

################################################################################
# Consumer access policies
#
# These are real IAM policies. A consuming bundle picks one by name and attaches
# the ARN to its own execution role, so access is granted by policy choice
# rather than by copying permissions into every consumer.
#
# Each one covers the KMS key as well as the table. A caller with DynamoDB
# permissions but no KMS permissions gets AccessDenied on every single call.
################################################################################

resource "aws_iam_policy" "read" {
  name_prefix = substr("${local.stem}-read-", 0, 32)
  description = "Read items from ${local.table_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:BatchGetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DescribeTable",
          "dynamodb:ConditionCheckItem",
        ]
        Resource = [
          aws_dynamodb_table.main.arn,
          "${aws_dynamodb_table.main.arn}/index/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = aws_kms_key.main.arn
      },
    ]
  })
}

resource "aws_iam_policy" "write" {
  name_prefix = substr("${local.stem}-write-", 0, 32)
  description = "Read and write items in ${local.table_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:BatchGetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DescribeTable",
          "dynamodb:ConditionCheckItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem",
        ]
        Resource = [
          aws_dynamodb_table.main.arn,
          "${aws_dynamodb_table.main.arn}/index/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = aws_kms_key.main.arn
      },
    ]
  })
}

resource "aws_iam_policy" "admin" {
  name_prefix = substr("${local.stem}-admin-", 0, 32)
  description = "Full control of ${local.table_name}, including table settings"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "dynamodb:*"
        Resource = [
          aws_dynamodb_table.main.arn,
          "${aws_dynamodb_table.main.arn}/index/*",
          "${aws_dynamodb_table.main.arn}/stream/*",
          "${aws_dynamodb_table.main.arn}/backup/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = aws_kms_key.main.arn
      },
    ]
  })
}
