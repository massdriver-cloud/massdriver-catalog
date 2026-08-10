resource "massdriver_resource" "site" {
  field = "site"
  name  = "Site ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id     = aws_cloudfront_distribution.site.id
    url    = "https://${aws_cloudfront_distribution.site.domain_name}"
    bucket = aws_s3_bucket.site.bucket
    region = var.region
  })
}
