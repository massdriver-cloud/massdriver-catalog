resource "massdriver_artifact" "storage" {
  field = "storage"
  name  = "Azure Storage ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id       = azurerm_storage_account.main.id
    name     = azurerm_storage_account.main.name
    endpoint = azurerm_storage_account.main.primary_blob_endpoint
    policies = [
      {
        id   = "read"
        name = "Read"
      },
      {
        id   = "write"
        name = "Write"
      }
    ]
    data = {
      resource_group_name   = azurerm_resource_group.main.name
      container_name        = azurerm_storage_container.main.name
      primary_access_key    = azurerm_storage_account.main.primary_access_key
      connection_string     = azurerm_storage_account.main.primary_connection_string
      primary_blob_endpoint = azurerm_storage_account.main.primary_blob_endpoint
    }
  })
}
