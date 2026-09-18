locals {
  name_prefix = var.md_metadata.name_prefix

  # Azure permits 3 to 24 lowercase letters and digits in a storage account
  # name. The Massdriver prefix holds hyphens, so remove them and truncate.
  account_name = substr(replace(lower(local.name_prefix), "/[^a-z0-9]/", ""), 0, 24)

  subnet_ids = [for subnet in var.network.subnets : subnet.id]
  has_logs   = try(var.logs.id, null) != null
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_storage_account" "main" {
  name                = local.account_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags

  account_tier             = "Standard"
  account_replication_type = replace(var.redundancy, "Standard_", "")
  account_kind             = "StorageV2"
  access_tier              = var.access_tier

  # Security defaults. A developer cannot weaken these from the form.
  https_traffic_only_enabled        = true
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true
  infrastructure_encryption_enabled = true
  shared_access_key_enabled         = false
  local_user_enabled                = false
  sftp_enabled                      = false

  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    versioning_enabled = var.versioning_enabled

    delete_retention_policy {
      days = var.retention_days
    }

    container_delete_retention_policy {
      days = var.retention_days
    }
  }

  # The account accepts traffic from the connected network only. Azure services
  # such as Monitor still reach the account through the bypass.
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = local.subnet_ids
  }
}

resource "azurerm_storage_container" "main" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Checkov CKV2_AZURE_21 asks for a record of every blob request. Connect a log
# workspace to turn it on. Without the connection the account writes no record.
resource "azurerm_monitor_diagnostic_setting" "blob" {
  count = local.has_logs ? 1 : 0

  name                       = "${local.name_prefix}-blob"
  target_resource_id         = "${azurerm_storage_account.main.id}/blobServices/default"
  log_analytics_workspace_id = var.logs.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}
