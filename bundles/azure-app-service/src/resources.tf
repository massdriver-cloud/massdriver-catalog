locals {
  service_url = "https://${azurerm_linux_web_app.main.default_hostname}"
}

resource "massdriver_resource" "application" {
  field = "application"
  name  = "Application ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    name             = azurerm_linux_web_app.main.name
    service_url      = local.service_url
    health_check_url = "${local.service_url}${var.health_check_path}"
    deployment_id    = azurerm_linux_web_app.main.id
    tags             = var.md_metadata.default_tags
  })
}
