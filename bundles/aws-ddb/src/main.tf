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
  table_name = var.table.name

  # Build attribute definitions from keys and indexes
  hash_key_attr = {
    name = var.table.hash_key.name
    type = var.table.hash_key.type
  }

  range_key_attr = var.table.range_key != null && try(var.table.range_key.name, null) != null ? {
    name = var.table.range_key.name
    type = var.table.range_key.type
  } : null

  gsi_attrs = [
    for gsi in try(var.indexes.global, []) : [
      { name = gsi.hash_key.name, type = gsi.hash_key.type },
      gsi.range_key != null && try(gsi.range_key.name, null) != null ? { name = gsi.range_key.name, type = gsi.range_key.type } : null
    ]
  ]

  lsi_attrs = [
    for lsi in try(var.indexes.local, []) : {
      name = lsi.range_key.name
      type = lsi.range_key.type
    }
  ]

  # Flatten and deduplicate attributes
  all_attrs_raw = concat(
    [local.hash_key_attr],
    local.range_key_attr != null ? [local.range_key_attr] : [],
    flatten(local.gsi_attrs),
    local.lsi_attrs
  )

  all_attrs = [
    for attr in distinct([for a in local.all_attrs_raw : a if a != null]) : attr
  ]

  # Deduplicate by name (keep first occurrence)
  attr_names_seen = {}
  unique_attrs = [
    for attr in local.all_attrs : attr
    if !contains(keys(local.attr_names_seen), attr.name) && can(local.attr_names_seen[attr.name] == attr.name ? false : true)
  ]
}

resource "aws_dynamodb_table" "main" {
  name         = local.table_name
  billing_mode = var.billing.mode
  hash_key     = var.table.hash_key.name
  range_key    = try(var.table.range_key.name, null)

  # Read/write capacity for provisioned mode
  read_capacity  = var.billing.mode == "PROVISIONED" ? var.billing.provisioned.read_capacity : null
  write_capacity = var.billing.mode == "PROVISIONED" ? var.billing.provisioned.write_capacity : null

  # Attribute definitions
  dynamic "attribute" {
    for_each = { for attr in local.all_attrs : attr.name => attr }
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Global Secondary Indexes
  dynamic "global_secondary_index" {
    for_each = try(var.indexes.global, [])
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key.name
      range_key          = try(global_secondary_index.value.range_key.name, null)
      projection_type    = try(global_secondary_index.value.projection_type, "ALL")
      non_key_attributes = try(global_secondary_index.value.projection_type, "ALL") == "INCLUDE" ? global_secondary_index.value.non_key_attributes : null

      # GSI capacity for provisioned mode
      read_capacity  = var.billing.mode == "PROVISIONED" ? var.billing.provisioned.read_capacity : null
      write_capacity = var.billing.mode == "PROVISIONED" ? var.billing.provisioned.write_capacity : null
    }
  }

  # Local Secondary Indexes
  dynamic "local_secondary_index" {
    for_each = try(var.indexes.local, [])
    content {
      name               = local_secondary_index.value.name
      range_key          = local_secondary_index.value.range_key.name
      projection_type    = try(local_secondary_index.value.projection_type, "ALL")
      non_key_attributes = try(local_secondary_index.value.projection_type, "ALL") == "INCLUDE" ? local_secondary_index.value.non_key_attributes : null
    }
  }

  # DynamoDB Streams
  stream_enabled   = try(var.stream.enabled, false)
  stream_view_type = try(var.stream.enabled, false) ? try(var.stream.view_type, "NEW_AND_OLD_IMAGES") : null

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = try(var.backup.point_in_time_recovery, false)
  }

  # Server-side encryption with AWS managed key
  server_side_encryption {
    enabled = true
  }

  # Deletion protection
  deletion_protection_enabled = try(var.backup.deletion_protection, false)

  lifecycle {
    prevent_destroy = false
  }
}

# IAM policy for read access
resource "aws_iam_policy" "read" {
  name        = "${var.md_metadata.name_prefix}-ddb-read"
  description = "Read access to DynamoDB table ${local.table_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadTable"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:BatchGetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DescribeTable",
          "dynamodb:DescribeTimeToLive"
        ]
        Resource = [
          aws_dynamodb_table.main.arn,
          "${aws_dynamodb_table.main.arn}/index/*"
        ]
      }
    ]
  })
}

# IAM policy for write access
resource "aws_iam_policy" "write" {
  name        = "${var.md_metadata.name_prefix}-ddb-write"
  description = "Write access to DynamoDB table ${local.table_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteTable"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.main.arn,
          "${aws_dynamodb_table.main.arn}/index/*"
        ]
      }
    ]
  })
}

# IAM policy for stream access (when enabled)
resource "aws_iam_policy" "stream" {
  count       = try(var.stream.enabled, false) ? 1 : 0
  name        = "${var.md_metadata.name_prefix}-ddb-stream"
  description = "Stream access to DynamoDB table ${local.table_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadStream"
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = [
          aws_dynamodb_table.main.stream_arn
        ]
      }
    ]
  })
}
