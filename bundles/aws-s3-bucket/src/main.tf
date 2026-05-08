data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
  keepers = {
    bucket_name_prefix = var.bucket_name_prefix
  }
}

locals {
  bucket_name = "${var.bucket_name_prefix}-${random_id.suffix.hex}"
  use_kms     = var.encryption == "sse-kms"
}

data "aws_iam_policy_document" "bucket_kms" {
  count = local.use_kms ? 1 : 0

  statement {
    sid    = "EnableRootAccountAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3Service"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "bucket" {
  count = local.use_kms ? 1 : 0

  description             = "KMS key for S3 bucket ${local.bucket_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.bucket_kms[0].json

  tags = {
    Name = "${local.bucket_name}-kms"
  }
}

resource "aws_kms_alias" "bucket" {
  count = local.use_kms ? 1 : 0

  name          = "alias/s3/${local.bucket_name}"
  target_key_id = aws_kms_key.bucket[0].key_id
}

resource "aws_s3_bucket" "main" {
  bucket = local.bucket_name

  # Set force_destroy = true only for ephemeral test buckets; production keeps it
  # false so an empty-then-delete flow is required.
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = var.object_ownership == "bucket-owner-enforced" ? "BucketOwnerEnforced" : "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status     = var.versioning == "enabled" ? "Enabled" : "Suspended"
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = local.use_kms ? aws_kms_key.bucket[0].arn : null
    }
    bucket_key_enabled = local.use_kms
  }
}

resource "aws_s3_bucket_cors_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = var.cors_origins
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.lifecycle_archive_after_days > 0 ? [1] : []
    content {
      id     = "archive-cold-objects"
      status = "Enabled"

      filter {}

      transition {
        days          = var.lifecycle_archive_after_days
        storage_class = "GLACIER_IR"
      }
    }
  }

  dynamic "rule" {
    for_each = var.lifecycle_expire_after_days > 0 ? [1] : []
    content {
      id     = "expire-objects"
      status = "Enabled"

      filter {}

      expiration {
        days = var.lifecycle_expire_after_days
      }
    }
  }

  dynamic "rule" {
    for_each = var.versioning == "enabled" ? [1] : []
    content {
      id     = "expire-noncurrent-versions"
      status = "Enabled"

      filter {}

      noncurrent_version_expiration {
        noncurrent_days = 90
      }
    }
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "main" {
  count = var.enable_intelligent_tiering ? 1 : 0

  bucket = aws_s3_bucket.main.id
  name   = "EntireBucket"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

# Access logging requires a sibling logs bucket. We only provision it when
# enable_access_logs is true to avoid paying for a bucket that has no logs.
resource "aws_s3_bucket" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket        = "${local.bucket_name}-logs"
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_logging" "main" {
  count = var.enable_access_logs ? 1 : 0

  bucket        = aws_s3_bucket.main.id
  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "access/"
}
