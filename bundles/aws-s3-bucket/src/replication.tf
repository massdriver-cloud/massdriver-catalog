# Optional cross-region replication. When the destination bucket ARN is set,
# we provision a replication role and a replication configuration on the
# source bucket. The destination bucket is owned out-of-band — typically by
# another aws-s3-bucket instance in a different region.

locals {
  replication_enabled = var.replication_destination_bucket_arn != ""
}

data "aws_iam_policy_document" "replication_assume" {
  count = local.replication_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count = local.replication_enabled ? 1 : 0

  name               = "${local.bucket_name}-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_assume[0].json
}

data "aws_iam_policy_document" "replication" {
  count = local.replication_enabled ? 1 : 0

  statement {
    sid       = "ReadSourceBucket"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.main.arn]
  }

  statement {
    sid = "ReadSourceObjects"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }

  statement {
    sid = "WriteDestinationObjects"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = ["${var.replication_destination_bucket_arn}/*"]
  }

  dynamic "statement" {
    for_each = local.use_kms ? [1] : []
    content {
      sid       = "DecryptSourceObjects"
      actions   = ["kms:Decrypt"]
      resources = [aws_kms_key.bucket[0].arn]
    }
  }
}

resource "aws_iam_role_policy" "replication" {
  count = local.replication_enabled ? 1 : 0

  name   = "${local.bucket_name}-replication"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

resource "aws_s3_bucket_replication_configuration" "main" {
  count = local.replication_enabled ? 1 : 0

  bucket = aws_s3_bucket.main.id
  role   = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}
