terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

locals {
  # Only set range_key attributes when a range key is provided
  has_range_key = var.range_key != null && var.range_key != ""

  # Capacity units only matter in PROVISIONED mode; PAY_PER_REQUEST ignores them
  is_provisioned = var.billing_mode == "PROVISIONED"

  # Stream view type only matters when streams are enabled
  stream_view_type = var.enable_streams ? var.stream_view_type : null
}

resource "aws_dynamodb_table" "main" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = var.hash_key

  # Provisioned capacity — ignored by DynamoDB when billing_mode = PAY_PER_REQUEST
  read_capacity  = local.is_provisioned ? var.read_capacity : null
  write_capacity = local.is_provisioned ? var.write_capacity : null

  # Optional sort key
  range_key = local.has_range_key ? var.range_key : null

  # Partition key attribute definition
  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  # Sort key attribute definition (only when range key is provided)
  dynamic "attribute" {
    for_each = local.has_range_key ? [1] : []
    content {
      name = var.range_key
      type = var.range_key_type
    }
  }

  # Hardcoded compliance: server-side encryption with AWS-managed key (CKV_AWS_28)
  server_side_encryption {
    enabled = true
  }

  # Hardcoded compliance: point-in-time recovery (CKV_AWS_28 / CKV2_AWS_16)
  point_in_time_recovery {
    enabled = true
  }

  # Hardcoded compliance: deletion protection prevents accidental table drops (CKV2_AWS_118)
  deletion_protection_enabled = true

  # DynamoDB Streams
  stream_enabled   = var.enable_streams
  stream_view_type = local.stream_view_type

  lifecycle {
    # Key schema, table name, and billing mode cannot be changed in-place —
    # changing them would require a new table, so treat them as immutable here too.
    ignore_changes = []
  }
}

# IAM policy: read-only access
resource "aws_iam_policy" "read_only" {
  name        = "${var.table_name}-read-only"
  description = "Read-only access to DynamoDB table ${var.table_name}"

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
        ]
        Resource = [
          aws_dynamodb_table.main.arn,
          "${aws_dynamodb_table.main.arn}/index/*",
        ]
      }
    ]
  })
}

# IAM policy: read-write access
resource "aws_iam_policy" "read_write" {
  name        = "${var.table_name}-read-write"
  description = "Read-write access to DynamoDB table ${var.table_name}"

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
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
        ]
        Resource = [
          aws_dynamodb_table.main.arn,
          "${aws_dynamodb_table.main.arn}/index/*",
        ]
      }
    ]
  })
}
