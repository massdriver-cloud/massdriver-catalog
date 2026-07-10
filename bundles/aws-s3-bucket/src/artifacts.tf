resource "massdriver_resource" "bucket" {
  field = "bucket"
  name  = "AWS S3 ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id          = aws_s3_bucket.main.arn
    bucket_name = aws_s3_bucket.main.bucket
    region      = var.region
    policies = [
      {
        id   = aws_iam_policy.read.arn
        name = "Read"
      },
      {
        id   = aws_iam_policy.read_write.arn
        name = "Read/Write"
      }
    ]
  })
}
