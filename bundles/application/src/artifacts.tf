resource "massdriver_resource" "application" {
  field = "application"
  name  = "Application ${var.md_metadata.name_prefix}"
  resource = jsonencode({
    deployment_id    = var.md_metadata.deployment.id
    name             = var.md_metadata.name_prefix
    service_url      = "https://${var.domain_name}"
    health_check_url = "https://${var.domain_name}${var.health_check_path}"
    tags             = var.md_metadata.default_tags
  })
}
