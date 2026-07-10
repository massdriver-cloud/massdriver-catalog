# Real IAM policies, published on the bucket artifact's `policies` list.
# Application bundles pick one from a dropdown ($md.enum over the list) and
# attach it to their runtime role — no hand-written IAM in the app bundle.

resource "aws_iam_policy" "read" {
  name        = "${var.md_metadata.name_prefix}-read"
  description = "Read-only access to the ${local.bucket_name} S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.main.arn}/*"
      },
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.main.arn
      }
    ]
  })
}

resource "aws_iam_policy" "read_write" {
  name        = "${var.md_metadata.name_prefix}-read-write"
  description = "Read/write access to the ${local.bucket_name} S3 bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      },
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.main.arn
      }
    ]
  })
}
