terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

provider "azurerm" {
  features {}

  client_id       = var.azure_service_principal.client_id
  client_secret   = var.azure_service_principal.client_secret
  tenant_id       = var.azure_service_principal.tenant_id
  subscription_id = var.azure_service_principal.subscription_id
}

locals {
  name_prefix = var.md_metadata.name_prefix
}

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = var.md_metadata.default_tags
}

resource "azurerm_network_ddos_protection_plan" "main" {
  count               = var.enable_ddos_protection ? 1 : 0
  name                = "${local.name_prefix}-ddos"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.md_metadata.default_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.cidr]
  dns_servers         = length(var.dns_servers) > 0 ? var.dns_servers : null
  tags                = var.md_metadata.default_tags

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.main[0].id
      enable = true
    }
  }
}

resource "azurerm_subnet" "main" {
  for_each = { for s in var.subnets : s.name => s }

  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.cidr]
  service_endpoints    = try(each.value.service_endpoints, [])
}

# CKV2_AZURE_31: Each subnet must be associated with a Network Security Group.
# We create one NSG per subnet with no rules (allow Azure defaults); operators
# add rules via separate NSG bundles or rule resources connected to this VNet.
resource "azurerm_network_security_group" "main" {
  for_each = { for s in var.subnets : s.name => s }

  name                = "${local.name_prefix}-${each.key}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.md_metadata.default_tags
}

resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = { for s in var.subnets : s.name => s }

  subnet_id                 = azurerm_subnet.main[each.key].id
  network_security_group_id = azurerm_network_security_group.main[each.key].id
}

# Network Watcher is a subscription-level singleton per region — Azure enforces
# only one per subscription per region. We do NOT create it here; it is assumed
# to already exist in the subscription (Azure creates a default one automatically
# in the NetworkWatcherRG resource group). Bundles that need flow logs should
# reference the existing Network Watcher via a data source.
