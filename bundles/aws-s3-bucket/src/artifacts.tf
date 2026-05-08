locals {
  policies = [
    {
      id   = aws_iam_policy.read.arn
      name = "Read"
    },
    {
      id   = aws_iam_policy.write.arn
      name = "Write"
    },
    {
      id   = aws_iam_policy.presign.arn
      name = "Presign Upload"
    },
    {
      id   = aws_iam_policy.admin.arn
      name = "Admin"
    },
  ]
}

resource "massdriver_artifact" "bucket" {
  field = "bucket"
  name  = "AWS S3 ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id           = aws_s3_bucket.main.arn
    name         = aws_s3_bucket.main.id
    region       = data.aws_region.current.name
    endpoint     = "https://${aws_s3_bucket.main.bucket_regional_domain_name}"
    domain_name  = aws_s3_bucket.main.bucket_regional_domain_name
    kms_key_arn  = local.use_kms ? aws_kms_key.bucket[0].arn : null
    cors_origins = var.cors_origins
    policies     = local.policies
  })
}
