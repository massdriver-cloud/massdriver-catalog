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
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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
  func_storage_name = replace(substr("${var.md_metadata.name_prefix}fn", 0, 24), "-", "")
  container_name    = var.storage.data.container_name
  connection_string = var.storage.data.connection_string
}

resource "azurerm_resource_group" "main" {
  name     = var.md_metadata.name_prefix
  location = var.region
  tags     = var.md_metadata.default_tags
}

# Function apps need their own storage account for runtime
resource "azurerm_storage_account" "function" {
  name                     = local.func_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.md_metadata.default_tags
}

resource "azurerm_service_plan" "main" {
  name                = "${var.md_metadata.name_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan

  tags = var.md_metadata.default_tags
}

resource "azurerm_linux_function_app" "main" {
  name                = var.md_metadata.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  service_plan_id            = azurerm_service_plan.main.id

  https_only = true

  site_config {
    application_stack {
      node_version = "20"
    }
    cors {
      allowed_origins = ["*"]
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "node"
    "WEBSITE_NODE_DEFAULT_VERSION"   = "~20"
    "BLOB_STORAGE_CONNECTION_STRING" = local.connection_string
    "BLOB_CONTAINER_NAME"            = local.container_name
    "STORAGE_POLICY"                 = var.storage_policy
  }

  tags = var.md_metadata.default_tags

}

# Deploy the function code
resource "azurerm_storage_container" "deployments" {
  name                  = "function-deployments"
  storage_account_name  = azurerm_storage_account.function.name
  container_access_type = "private"
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
}

resource "azurerm_storage_blob" "function_code" {
  name                   = "function-${data.archive_file.function.output_md5}.zip"
  storage_account_name   = azurerm_storage_account.function.name
  storage_container_name = azurerm_storage_container.deployments.name
  type                   = "Block"
  source                 = data.archive_file.function.output_path
}

data "azurerm_storage_account_sas" "function" {
  connection_string = azurerm_storage_account.function.primary_connection_string
  https_only        = true
  start             = "2024-01-01"
  expiry            = "2030-01-01"

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

resource "azurerm_function_app_function" "api" {
  name            = "api"
  function_app_id = azurerm_linux_function_app.main.id
  language        = "Javascript"

  config_json = jsonencode({
    bindings = [
      {
        authLevel = "anonymous"
        type      = "httpTrigger"
        direction = "in"
        name      = "req"
        methods   = ["get", "post", "delete"]
        route     = "{*path}"
      },
      {
        type      = "http"
        direction = "out"
        name      = "res"
      }
    ]
  })

  file {
    name    = "index.js"
    content = file("${path.module}/function/api/index.js")
  }
}

output "function_app_url" {
  value       = "https://${azurerm_linux_function_app.main.default_hostname}"
  description = "The URL of the function app"
}

output "api_endpoint" {
  value       = "https://${azurerm_linux_function_app.main.default_hostname}/api"
  description = "The API endpoint URL"
}
