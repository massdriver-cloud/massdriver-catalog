resource "massdriver_resource" "bucket" {
  field = "bucket"
  name  = "S3 Bucket (${var.md_metadata.name_prefix})"
  resource = jsonencode({
    id          = aws_s3_bucket.main.arn
    name        = aws_s3_bucket.main.bucket
    endpoint    = "https://${aws_s3_bucket.main.bucket}.s3.${var.region}.amazonaws.com"
    region      = var.region
    kms_key_arn = aws_kms_key.bucket.arn
    policies = [
      { id = aws_iam_policy.read_only.arn, name = "read-only" },
      { id = aws_iam_policy.read_write.arn, name = "read-write" },
    ]
  })
}
