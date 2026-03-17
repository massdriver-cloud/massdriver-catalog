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
    external_id = var.aws_authentication.external_id
  }

  default_tags {
    tags = var.md_metadata.default_tags
  }
}

locals {
  use_range_key    = var.range_key != null && var.range_key != ""
  stream_view_type = var.enable_streams ? var.stream_view_type : null
}

resource "aws_dynamodb_table" "main" {
  name         = var.table_name
  billing_mode = var.billing_mode

  # Only set capacity when PROVISIONED — ignored for PAY_PER_REQUEST
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  hash_key  = var.hash_key
  range_key = local.use_range_key ? var.range_key : null

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  dynamic "attribute" {
    for_each = local.use_range_key ? [1] : []
    content {
      name = var.range_key
      type = var.range_key_type
    }
  }

  # CKV_AWS_28: Enable Point-in-Time Recovery (hardcoded for compliance)
  point_in_time_recovery {
    enabled = true
  }

  # CKV_AWS_119: Encryption at rest with AWS-managed key (hardcoded for compliance)
  server_side_encryption {
    enabled = true
  }

  # CKV_AWS_341: Enable deletion protection (hardcoded for compliance)
  deletion_protection_enabled = true

  # Streams — optional, configurable
  stream_enabled   = var.enable_streams
  stream_view_type = local.stream_view_type

  lifecycle {
    # table_name, hash_key, range_key, and billing_mode are all marked $md.immutable in
    # massdriver.yaml, so Massdriver will block UI changes. The prevent_destroy guard
    # here provides an extra layer at the Terraform level.
    prevent_destroy = true
  }
}

# Read-only IAM policy
resource "aws_iam_policy" "read_only" {
  name        = "${var.md_metadata.name_prefix}-dynamodb-read"
  description = "Read-only access to the ${var.table_name} DynamoDB table"

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

# Read-write IAM policy
resource "aws_iam_policy" "read_write" {
  name        = "${var.md_metadata.name_prefix}-dynamodb-read-write"
  description = "Read-write access to the ${var.table_name} DynamoDB table"

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
