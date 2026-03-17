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
  table_name = var.md_metadata.name_prefix
}

resource "aws_dynamodb_table" "main" {
  name             = local.table_name
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = var.partition_key.name
  range_key        = var.sort_key.enabled ? var.sort_key.name : null
  stream_enabled   = true
  stream_view_type = var.stream_view_type

  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = var.partition_key.name
    type = var.partition_key.type
  }

  dynamic "attribute" {
    for_each = var.sort_key.enabled ? [1] : []
    content {
      name = var.sort_key.name
      type = var.sort_key.type
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }
}
