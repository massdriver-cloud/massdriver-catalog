locals {
  name_prefix  = var.md_metadata.name_prefix
  factory_name = substr(replace(lower(local.name_prefix), "/[^a-z0-9-]/", ""), 0, 63)
  has_bucket   = try(var.bucket.name, null) != null
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_data_factory" "main" {
  name                = local.factory_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags

  managed_virtual_network_enabled = var.managed_virtual_network
  public_network_enabled          = var.public_network_enabled

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_data_factory_integration_runtime_azure" "main" {
  count = var.managed_virtual_network ? 1 : 0

  name            = "default"
  data_factory_id = azurerm_data_factory.main.id
  location        = azurerm_resource_group.main.location

  virtual_network_enabled = true
  compute_type            = "General"
  core_count              = var.integration_runtime_cores
  time_to_live_min        = var.integration_runtime_ttl_minutes
}

# The factory reads and writes the connected container with its own identity.
resource "azurerm_role_assignment" "bucket" {
  count = local.has_bucket ? 1 : 0

  scope                = var.bucket.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.main.identity[0].principal_id
}
