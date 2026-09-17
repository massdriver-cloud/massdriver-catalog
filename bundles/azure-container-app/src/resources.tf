locals {
  scheme       = var.public_ingress ? "https://" : "http://"
  service_url  = "${local.scheme}${azurerm_container_app.main.ingress[0].fqdn}"
  health_check = "${local.service_url}${var.health_check_path}"
}

resource "massdriver_resource" "application" {
  field = "application"
  name  = "Application ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    name             = azurerm_container_app.main.name
    service_url      = local.service_url
    health_check_url = local.health_check
    deployment_id    = azurerm_container_app.main.latest_revision_name
    tags             = var.md_metadata.default_tags
  })
}
