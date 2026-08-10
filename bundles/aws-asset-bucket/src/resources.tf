resource "massdriver_resource" "bucket" {
  field = "bucket"
  name  = "Assets ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id       = aws_s3_bucket.main.arn
    name     = aws_s3_bucket.main.bucket
    endpoint = "https://${aws_s3_bucket.main.bucket_regional_domain_name}"
    region   = var.region
    policies = [
      {
        id   = aws_iam_policy.read.arn
        name = "read"
      },
      {
        id   = aws_iam_policy.write.arn
        name = "write"
      },
      {
        id   = aws_iam_policy.admin.arn
        name = "admin"
      },
    ]
  })
}
