resource "massdriver_artifact" "application" {
  field = "application"
  name  = "Application ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    deployment_id = var.md_metadata.deployment.id
    name          = var.md_metadata.name_prefix
    tags          = var.md_metadata.default_tags
  })
}
