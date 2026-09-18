resource "massdriver_resource" "logs" {
  field = "logs"
  name  = "Log Workspace ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id             = azurerm_log_analytics_workspace.main.id
    name           = azurerm_log_analytics_workspace.main.name
    region         = azurerm_log_analytics_workspace.main.location
    retention_days = var.retention_days
  })
}
