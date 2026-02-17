resource "massdriver_artifact" "application" {
  field = "application"
  name  = "Azure Function App ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    deployment_id = var.md_metadata.deployment.id
    name          = var.md_metadata.name_prefix
    service_url   = "https://${azurerm_linux_function_app.main.default_hostname}"
    tags          = var.md_metadata.default_tags
  })
}
