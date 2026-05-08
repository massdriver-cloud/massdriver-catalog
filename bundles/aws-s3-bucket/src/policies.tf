# Example IAM policies surfaced through the artifact's `policies` array.
# These are real, attachable policies — bind one to a workload's IAM role
# (e.g. an IRSA service account) to grant scoped bucket access.

locals {
  bucket_arn      = aws_s3_bucket.main.arn
  bucket_objects  = "${aws_s3_bucket.main.arn}/*"
  bucket_kms_arns = local.use_kms ? [aws_kms_key.bucket[0].arn] : []
}

data "aws_iam_policy_document" "read" {
  statement {
    sid       = "ReadBucket"
    actions   = ["s3:GetObject", "s3:GetObjectTagging", "s3:GetObjectVersion"]
    resources = [local.bucket_objects]
  }
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [local.bucket_arn]
  }
  dynamic "statement" {
    for_each = local.use_kms ? [1] : []
    content {
      sid       = "DecryptObjects"
      actions   = ["kms:Decrypt"]
      resources = local.bucket_kms_arns
    }
  }
}

data "aws_iam_policy_document" "write" {
  source_policy_documents = [data.aws_iam_policy_document.read.json]
  statement {
    sid       = "WriteObjects"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging"]
    resources = [local.bucket_objects]
  }
  dynamic "statement" {
    for_each = local.use_kms ? [1] : []
    content {
      sid       = "EncryptObjects"
      actions   = ["kms:GenerateDataKey", "kms:Encrypt"]
      resources = local.bucket_kms_arns
    }
  }
}

data "aws_iam_policy_document" "presign" {
  statement {
    sid       = "PresignUploads"
    actions   = ["s3:PutObject"]
    resources = [local.bucket_objects]
  }
  dynamic "statement" {
    for_each = local.use_kms ? [1] : []
    content {
      sid       = "PresignKMS"
      actions   = ["kms:GenerateDataKey"]
      resources = local.bucket_kms_arns
    }
  }
}

data "aws_iam_policy_document" "admin" {
  source_policy_documents = [data.aws_iam_policy_document.write.json]
  statement {
    sid       = "ManageBucketSettings"
    actions   = ["s3:PutBucketPolicy", "s3:GetBucketPolicy", "s3:PutBucketAcl", "s3:GetBucketAcl"]
    resources = [local.bucket_arn]
  }
}

resource "aws_iam_policy" "read" {
  name        = "${local.bucket_name}-read"
  description = "Read-only access to the ${local.bucket_name} bucket"
  policy      = data.aws_iam_policy_document.read.json
}

resource "aws_iam_policy" "write" {
  name        = "${local.bucket_name}-write"
  description = "Read+write access to the ${local.bucket_name} bucket"
  policy      = data.aws_iam_policy_document.write.json
}

resource "aws_iam_policy" "presign" {
  name        = "${local.bucket_name}-presign"
  description = "Object PUT permission for presigned URL uploads to ${local.bucket_name}"
  policy      = data.aws_iam_policy_document.presign.json
}

resource "aws_iam_policy" "admin" {
  name        = "${local.bucket_name}-admin"
  description = "Full administrative access to the ${local.bucket_name} bucket"
  policy      = data.aws_iam_policy_document.admin.json
}
