terraform {
  required_version = ">= 1.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
  keepers = {
    bucket_name_prefix = var.bucket_name_prefix
  }
}

locals {
  region      = "us-east-1"
  account_id  = "123456789012"
  bucket_name = "${var.bucket_name_prefix}-${random_id.suffix.hex}"
  bucket_arn  = "arn:aws:s3:::${local.bucket_name}"
  domain_name = "${local.bucket_name}.s3.${local.region}.amazonaws.com"
  endpoint    = "https://${local.domain_name}"
  kms_key_arn = var.encryption == "sse-kms" ? "arn:aws:kms:${local.region}:${local.account_id}:key/${random_id.suffix.hex}-${random_id.suffix.hex}" : null

  policies = [
    {
      id   = "arn:aws:iam::${local.account_id}:policy/${local.bucket_name}-read"
      name = "Read"
    },
    {
      id   = "arn:aws:iam::${local.account_id}:policy/${local.bucket_name}-write"
      name = "Write"
    },
    {
      id   = "arn:aws:iam::${local.account_id}:policy/${local.bucket_name}-presign"
      name = "Presign Upload"
    },
    {
      id   = "arn:aws:iam::${local.account_id}:policy/${local.bucket_name}-admin"
      name = "Admin"
    },
  ]
}
