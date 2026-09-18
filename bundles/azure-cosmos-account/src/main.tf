locals {
  name_prefix  = var.md_metadata.name_prefix
  account_name = substr(replace(lower(local.name_prefix), "/[^a-z0-9-]/", ""), 0, 44)
  subnet_ids   = [for subnet in var.network.subnets : subnet.id]
  is_mongo     = var.api == "mongo"
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_cosmosdb_account" "main" {
  name                = local.account_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags

  offer_type   = "Standard"
  kind         = local.is_mongo ? "MongoDB" : "GlobalDocumentDB"
  free_tier_enabled = false

  # The account answers inside the network only. Every other source gets a
  # refusal, and no rule accepts the open internet.
  is_virtual_network_filter_enabled = true
  public_network_access_enabled     = true
  local_authentication_enabled      = true
  minimal_tls_version               = "Tls12"

  # A key cannot change the account itself. Checkov CKV_AZURE_132.
  access_key_metadata_writes_enabled = false

  dynamic "virtual_network_rule" {
    for_each = toset(local.subnet_ids)

    content {
      id = virtual_network_rule.value
    }
  }

  dynamic "capabilities" {
    for_each = var.capacity_mode == "Serverless" ? ["EnableServerless"] : []

    content {
      name = capabilities.value
    }
  }

  dynamic "capabilities" {
    for_each = local.is_mongo ? ["EnableMongo"] : []

    content {
      name = capabilities.value
    }
  }

  consistency_policy {
    consistency_level       = var.consistency
    max_interval_in_seconds = var.consistency == "BoundedStaleness" ? 300 : null
    max_staleness_prefix    = var.consistency == "BoundedStaleness" ? 100000 : null
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
    zone_redundant    = var.zone_redundant
  }

  backup {
    type                = "Periodic"
    interval_in_minutes = var.backup_interval_minutes
    retention_in_hours  = 8
    storage_redundancy  = "Local"
  }
}

resource "azurerm_cosmosdb_sql_database" "main" {
  count = local.is_mongo ? 0 : 1

  name                = var.database_name
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  throughput          = var.capacity_mode == "Provisioned" ? var.throughput : null
}

resource "azurerm_cosmosdb_mongo_database" "main" {
  count = local.is_mongo ? 1 : 0

  name                = var.database_name
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  throughput          = var.capacity_mode == "Provisioned" ? var.throughput : null
}
