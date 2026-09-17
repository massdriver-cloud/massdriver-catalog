resource "massdriver_resource" "bucket" {
  field = "bucket"
  name  = "Object Storage ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id         = azurerm_storage_account.main.id
    name       = azurerm_storage_account.main.name
    container  = azurerm_storage_container.main.name
    endpoint   = "${azurerm_storage_account.main.primary_blob_endpoint}${azurerm_storage_container.main.name}"
    region     = azurerm_resource_group.main.location
    account_id = var.azure_service_principal.subscription_id

    # The identifier is the Azure built-in role. A consumer assigns the role to
    # its own identity, so no access key leaves this bundle.
    policies = [
      {
        id   = "Storage Blob Data Reader"
        name = "Read"
      },
      {
        id   = "Storage Blob Data Contributor"
        name = "Read and write"
      },
      {
        id   = "Storage Blob Data Owner"
        name = "Full control"
      }
    ]
  })
}
