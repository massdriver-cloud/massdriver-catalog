terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.4"
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

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # S3 bucket names are globally unique across all AWS accounts, so we append
  # a random suffix. Names must be lowercase and at most 63 characters —
  # truncate the prefix, never the suffix, so uniqueness survives long names.
  bucket_name = lower("${substr(var.md_metadata.name_prefix, 0, 54)}-${random_id.suffix.hex}")

  # Object lock requires versioning; force it on whenever lock is enabled so
  # the two toggles can never produce an invalid bucket.
  versioning_enabled = var.versioning_enabled || var.object_lock
}

resource "aws_s3_bucket" "main" {
  bucket              = local.bucket_name
  object_lock_enabled = var.object_lock

  # Demo catalog: let decommission succeed even with objects in the bucket.
  # Remove for buckets holding data you can't lose.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    # local.versioning_enabled ORs in var.object_lock — S3 rejects a locked
    # bucket with versioning suspended, so the invalid combination is
    # unreachable by construction.
    status = local.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Private: block every form of public access. Public read: open the gates so
# the bucket policy below can take effect.
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = var.access == "private"
  block_public_policy     = var.access == "private"
  ignore_public_acls      = var.access == "private"
  restrict_public_buckets = var.access == "private"
}

resource "aws_s3_bucket_policy" "public_read" {
  count = var.access == "public_read" ? 1 : 0

  bucket = aws_s3_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadObjects"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })

  # The policy is rejected while BlockPublicPolicy is still true.
  depends_on = [aws_s3_bucket_public_access_block.main]
}

# GOVERNANCE, not COMPLIANCE: governance mode still makes versions immutable
# for everyone, but admins granted s3:BypassGovernanceRetention can undo a
# mistake. COMPLIANCE mode is irreversible even for the account root — the
# wrong default for a demo catalog.
resource "aws_s3_bucket_object_lock_configuration" "main" {
  count = var.object_lock ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.object_lock_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  count = var.expire_noncurrent_versions_days > 0 ? 1 : 0

  bucket = aws_s3_bucket.main.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.expire_noncurrent_versions_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}
