terraform {
  required_version = ">= 1.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}

  # The storage account turns off the shared access key. Without this flag the
  # provider polls the blob endpoint with key authentication and gets a 403.
  storage_use_azuread = true

  client_id       = var.azure_service_principal.client_id
  tenant_id       = var.azure_service_principal.tenant_id
  client_secret   = var.azure_service_principal.client_secret
  subscription_id = var.azure_service_principal.subscription_id
}
