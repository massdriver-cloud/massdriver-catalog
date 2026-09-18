locals {
  name_prefix = var.md_metadata.name_prefix

  # The IP address management system owns the ranges. When an allocation is
  # connected, it wins over the value in the form.
  cidr = try(var.allocation.cidr, null) != null ? var.allocation.cidr : var.cidr

  # Azure delegates a subnet to one service only. The keys match the
  # `delegation` enum in massdriver.yaml.
  delegations = {
    # Azure rewrites the Container Apps action to `join/action` on read. Declare
    # the value that Azure returns, or every deployment shows the same change.
    containerapps = {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
    appservice = {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
    postgres = {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }

  # `delegation` is optional in the schema. Normalize a null to "none" so that
  # the lookup below never fails.
  subnets = {
    for subnet in var.subnets : subnet.name => merge(subnet, {
      delegation = try(subnet.delegation, null) == null ? "none" : subnet.delegation
    })
  }
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_virtual_network" "main" {
  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [local.cidr]
  dns_servers         = var.dns_servers
  tags                = var.md_metadata.default_tags
}

resource "azurerm_subnet" "main" {
  for_each = local.subnets

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.cidr]

  # A storage account, a key vault, a SQL server, or a Cosmos DB account accepts
  # traffic from a subnet only when the subnet carries the matching service
  # endpoint.
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.Sql",
    "Microsoft.AzureCosmosDB",
  ]

  dynamic "delegation" {
    for_each = try([local.delegations[each.value.delegation]], [])

    content {
      name = each.value.delegation

      service_delegation {
        name    = delegation.value.name
        actions = delegation.value.actions
      }
    }
  }
}
