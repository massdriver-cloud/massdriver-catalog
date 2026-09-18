locals {
  name_prefix = var.md_metadata.name_prefix

  # Azure runs a flexible server inside a subnet that carries the PostgreSQL
  # delegation. The network bundle sets that delegation on one subnet.
  delegated_subnets = [
    for subnet in var.network.subnets : subnet
    if try(subnet.delegation, "") == "postgres"
  ]

  subnet_id = try(local.delegated_subnets[0].id, null)
}

resource "random_password" "admin" {
  length      = 32
  special     = true
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  # Azure rejects these characters in a PostgreSQL password.
  override_special = "!#%*()-_=+[]{}<>:?"
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

# A flexible server inside a network resolves its own name through a private
# zone. Azure rejects the server without one.
resource "azurerm_private_dns_zone" "main" {
  name                = "${local.name_prefix}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.md_metadata.default_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = local.name_prefix
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = var.network.id
  registration_enabled  = false
  tags                  = var.md_metadata.default_tags
}

resource "azurerm_postgresql_flexible_server" "main" {
  lifecycle {
    # Azure picks the zone at creation, and the bundle never sets one. Without
    # this rule every later deployment tries to unset the zone, and Azure
    # refuses the change.
    ignore_changes = [zone, high_availability[0].standby_availability_zone]

    precondition {
      condition     = local.subnet_id != null
      error_message = "The connected network holds no subnet with the PostgreSQL delegation. Add one to the network, then deploy again."
    }
  }

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags

  version    = var.db_version
  sku_name   = var.instance_size
  storage_mb = var.storage_gb * 1024

  administrator_login    = var.username
  administrator_password = random_password.admin.result

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup

  # The server has no public endpoint. It answers inside the network only.
  public_network_access_enabled = false
  delegated_subnet_id           = local.subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.main.id

  dynamic "high_availability" {
    for_each = var.high_availability ? [1] : []

    content {
      mode = "ZoneRedundant"
    }
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.main]
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Log every connection and every disconnection. An auditor asks for this.
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "connection_throttling" {
  name      = "connection_throttle.enable"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}
