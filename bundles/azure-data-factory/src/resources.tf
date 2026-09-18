resource "massdriver_resource" "pipeline" {
  field = "pipeline"
  name  = "Data Factory ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id           = azurerm_data_factory.main.id
    name         = azurerm_data_factory.main.name
    region       = azurerm_resource_group.main.location
    studio_url   = "https://adf.azure.com/en/home?factory=${azurerm_data_factory.main.id}"
    principal_id = azurerm_data_factory.main.identity[0].principal_id
  })
}
