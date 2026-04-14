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

# CKV_AZURE_230 / general compliance: Virtual WAN type Standard enables
# full mesh routing, VNet peering, and ExpressRoute — required for production.
resource "azurerm_virtual_wan" "main" {
  name                = "${local.name_prefix}-vwan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  type                = var.wan_type
  tags                = var.md_metadata.default_tags

  # Disable legacy branch-to-branch traffic by default; enable explicitly if needed
  allow_branch_to_branch_traffic    = false
  office365_local_breakout_category = "None"
}

resource "azurerm_virtual_hub" "main" {
  name                = "${local.name_prefix}-hub"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  virtual_wan_id      = azurerm_virtual_wan.main.id
  address_prefix      = var.hub_address_prefix
  tags                = var.md_metadata.default_tags
}

# Site-to-Site VPN Gateway — optional, for branch office connectivity
resource "azurerm_vpn_gateway" "main" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "${local.name_prefix}-vpngw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  virtual_hub_id      = azurerm_virtual_hub.main.id
  scale_unit          = var.vpn_gateway_scale_unit
  tags                = var.md_metadata.default_tags
}
