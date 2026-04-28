resource "massdriver_artifact" "azure_function_app" {
  field = "azure_function_app"
  name  = "Azure Function App ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id                               = azurerm_linux_function_app.main.id
    name                             = azurerm_linux_function_app.main.name
    resource_group_name              = azurerm_resource_group.main.name
    location                         = azurerm_linux_function_app.main.location
    default_hostname                 = azurerm_linux_function_app.main.default_hostname
    storage_account_name             = azurerm_storage_account.main.name
    app_insights_instrumentation_key = azurerm_application_insights.main.instrumentation_key
    app_insights_connection_string   = azurerm_application_insights.main.connection_string
    principal_id                     = azurerm_linux_function_app.main.identity[0].principal_id
  })
}
