resource "massdriver_artifact" "application" {
  field = "application"
  name  = "Static Site ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    deployment_id = var.md_metadata.deployment.id
    name          = var.site_name
    url           = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
    tags          = var.md_metadata.default_tags
  })
}
