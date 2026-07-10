resource "massdriver_resource" "app" {
  field = "app"
  name  = "Static site ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id          = aws_s3_bucket.main.arn
    url         = "http://${aws_s3_bucket_website_configuration.main.website_endpoint}"
    health_path = "/"
  })
}
