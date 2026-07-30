locals {
  name_prefix = var.md_metadata.name_prefix
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "bucket" {
  description             = "SSE-KMS key for ${var.bucket_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowRootAccountFullAccess"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
  tags = var.md_metadata.default_tags
}

resource "aws_kms_alias" "bucket" {
  name          = "alias/${local.name_prefix}-bucket"
  target_key_id = aws_kms_key.bucket.key_id
}

resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
  # checkov:skip=CKV_AWS_144: cross-region replication is a per-app DR
  # decision, not a default for this shared bucket bundle. Add it (a second
  # bucket + replication IAM role in another region) when a specific app's
  # RPO/RTO actually requires it.
  # checkov:skip=CKV_AWS_18: access logging needs a separate log-destination
  # bucket, which this generic, standalone bucket bundle doesn't provision.
  # Point logging at a shared logging bucket once one exists in the catalog.
  # checkov:skip=CKV2_AWS_62: no downstream consumer for bucket change
  # events in this catalog yet. Add an SNS/EventBridge notification when a
  # consuming app actually needs to react to object creation/deletion.
  force_destroy = var.force_destroy
  tags          = var.md_metadata.default_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = var.enable_versioning ? "Enabled" : "Disabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.bucket.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Private by default — not configurable. Public asset serving belongs behind
# a CDN (CloudFront), not on the bucket itself.
resource "aws_s3_bucket_public_access_block" "main" {
  bucket                  = aws_s3_bucket.main.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Scoped IAM policies a consuming app attaches to its IRSA role ---

resource "aws_iam_policy" "read_only" {
  name_prefix = "${local.name_prefix}-ro-"
  description = "Read-only access to ${var.bucket_name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.main.arn, "${aws_s3_bucket.main.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [aws_kms_key.bucket.arn]
      }
    ]
  })
}

resource "aws_iam_policy" "read_write" {
  name_prefix = "${local.name_prefix}-rw-"
  description = "Read-write access to ${var.bucket_name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.main.arn, "${aws_s3_bucket.main.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [aws_kms_key.bucket.arn]
      }
    ]
  })
}
