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
  subscription_id = var.azure_authentication.subscription_id
  tenant_id       = var.azure_authentication.tenant_id
  client_id       = var.azure_authentication.client_id
  client_secret   = var.azure_authentication.client_secret
}

locals {
  # Storage account names must be 3-24 chars, lowercase alphanumeric only
  storage_account_name = replace(substr("${var.md_metadata.name_prefix}", 0, 24), "-", "")
}

resource "azurerm_resource_group" "main" {
  name     = var.md_metadata.name_prefix
  location = var.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }

  tags = var.md_metadata.default_tags
}

resource "azurerm_storage_container" "main" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Role assignments for read and write access
data "azurerm_client_config" "current" {}

output "storage_account_name" {
  value       = azurerm_storage_account.main.name
  description = "The name of the storage account"
}

output "container_name" {
  value       = azurerm_storage_container.main.name
  description = "The name of the blob container"
}

output "primary_blob_endpoint" {
  value       = azurerm_storage_account.main.primary_blob_endpoint
  description = "The primary blob endpoint URL"
}
