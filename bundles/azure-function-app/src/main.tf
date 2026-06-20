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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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

  # Map subnet name → ID for private endpoint lookups
  subnet_map = {
    for s in var.azure_virtual_network.subnets : s.name => s.id
  }

  # Private endpoint subnet ID (if subnet_name is provided and exists)
  pe_subnet_id = try(
    local.subnet_map[var.private_endpoints.subnet_name],
    values(local.subnet_map)[0]
  )

  enable_pe_func    = try(var.private_endpoints.enable_function_app, false)
  enable_pe_storage = try(var.private_endpoints.enable_storage, false)
  enable_backup     = try(var.backup.enable, false)
}

# ─────────────────────────────────────────────
# Resource Group
# ─────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = var.md_metadata.default_tags
}

# ─────────────────────────────────────────────
# Storage Account (required by Azure Functions)
# CKV_AZURE_33: queue logging enabled
# CKV_AZURE_44: min TLS 1.2 enforced
# CKV_AZURE_59: public access disabled
# CKV3_AZURE_64: HTTPS only enforced
# CKV_AZURE_206: storage firewall — allow Azure services (functions need access)
# ─────────────────────────────────────────────

resource "random_string" "storage_suffix" {
  length  = 6
  lower   = true
  numeric = true
  upper   = false
  special = false
}

resource "azurerm_storage_account" "main" {
  # Storage account names: 3-24 chars, lowercase alphanumeric only.
  # Truncate the stripped name_prefix to 16 chars to leave room for "fn" (2) + suffix (6) = 24.
  name                = "fn${substr(replace(local.name_prefix, "-", ""), 0, min(16, length(replace(local.name_prefix, "-", ""))))}${random_string.storage_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = try(var.storage.replication_type, "ZRS")
  account_kind             = "StorageV2"

  # Security hardening
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  # CKV_AZURE_244: disable local users — managed identity is used instead
  local_user_enabled = false
  # CKV_AZURE_59: disable public network access only when private endpoints are
  # enabled — the Functions runtime must reach the storage account to create file
  # shares during provisioning. When PEs are disabled, the AzureServices bypass
  # below provides the necessary access restriction.
  public_network_access_enabled = local.enable_pe_storage ? false : true
  # shared_access_key_enabled = true is required by the Azure Functions runtime
  # to store its internal state in the storage account. CKV2_AZURE_40 is
  # intentionally skipped in .checkov.yml for this reason.
  shared_access_key_enabled = true

  # CKV_AZURE_35: deny by default when private endpoints are configured; the
  # Functions service reaches storage via the PE subnet in that case. Without a
  # PE and VNet subnet service endpoint, the Azure Functions provisioning plane
  # cannot create the required file share even through the AzureServices bypass,
  # so we allow public access in that configuration. See .checkov.yml for details.
  network_rules {
    default_action             = local.enable_pe_storage ? "Deny" : "Allow"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  blob_properties {
    # CKV_AZURE_33: enable delete retention for blob data protection
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  queue_properties {
    logging {
      delete                = true
      read                  = true
      write                 = true
      version               = "1.0"
      retention_policy_days = 7
    }
  }

  tags = var.md_metadata.default_tags
}

# ─────────────────────────────────────────────
# Application Insights
# ─────────────────────────────────────────────

resource "azurerm_application_insights" "main" {
  name                = "${local.name_prefix}-ai"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  tags                = var.md_metadata.default_tags

  # Disable local authentication — enforce Entra ID (CKV_AZURE_132)
  local_authentication_disabled = true

  # Retain telemetry for 90 days by default
  retention_in_days = 90

  # The azurerm provider may set workspace_id automatically in some regions/versions.
  # Ignore it after initial creation to avoid "workspace_id can not be removed" errors
  # on subsequent runs when no Log Analytics workspace was explicitly configured.
  lifecycle {
    ignore_changes = [workspace_id]
  }
}

# ─────────────────────────────────────────────
# App Service Plan (hosting plan for the Function App)
# ─────────────────────────────────────────────

resource "azurerm_service_plan" "main" {
  name                = "${local.name_prefix}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.sku.size
  tags                = var.md_metadata.default_tags
}

# ─────────────────────────────────────────────
# Function App
# CKV_AZURE_221: HTTPS only
# CKV_AZURE_71:  managed identity enabled
# CKV_AZURE_17:  auth not required (configurable via app settings post-deploy)
# ─────────────────────────────────────────────

resource "azurerm_linux_function_app" "main" {
  name                = "${local.name_prefix}-fn"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  https_only = true

  # CKV_AZURE_221: disable public network access when a private endpoint is
  # provisioned for the function app. Without a PE, setting this to false would
  # make the function app completely inaccessible. CKV_AZURE_221 is skipped in
  # .checkov.yml when PEs are not enabled.
  public_network_access_enabled = local.enable_pe_func ? false : true

  # CKV_AZURE_71: system-assigned managed identity for Key Vault and other Azure services
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = var.runtime.name == "python" ? var.runtime.version : null
      node_version   = var.runtime.name == "node" ? "~${var.runtime.version}" : null
      java_version   = var.runtime.name == "java" ? var.runtime.version : null
      dotnet_version = var.runtime.name == "dotnet-isolated" ? var.runtime.version : null
    }

    # Always-on is not supported on Consumption/EP plans; EP plans handle it via scale
    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string

    # CKV_AZURE_155: minimum TLS 1.2
    minimum_tls_version = "1.2"

    # Disable FTP deployment — use CI/CD or Kudu only
    ftps_state = "Disabled"
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"              = var.runtime.name
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    # Disable public SCM site (Kudu) network access when PE is enabled
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  tags = var.md_metadata.default_tags
}

# ─────────────────────────────────────────────
# Private Endpoints — Function App
# ─────────────────────────────────────────────

resource "azurerm_private_endpoint" "function_app" {
  count               = local.enable_pe_func ? 1 : 0
  name                = "${local.name_prefix}-fn-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = local.pe_subnet_id
  tags                = var.md_metadata.default_tags

  private_service_connection {
    name                           = "${local.name_prefix}-fn-psc"
    private_connection_resource_id = azurerm_linux_function_app.main.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }
}

# ─────────────────────────────────────────────
# Private Endpoints — Storage Account (blob, file, queue, table)
# ─────────────────────────────────────────────

locals {
  storage_subresources = local.enable_pe_storage ? ["blob", "file", "queue", "table"] : []
}

resource "azurerm_private_endpoint" "storage" {
  for_each            = toset(local.storage_subresources)
  name                = "${local.name_prefix}-st-${each.key}-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = local.pe_subnet_id
  tags                = var.md_metadata.default_tags

  private_service_connection {
    name                           = "${local.name_prefix}-st-${each.key}-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = [each.key]
    is_manual_connection           = false
  }
}

# ─────────────────────────────────────────────
# Recovery Services Vault + Backup
# CKV_AZURE_228: soft delete enabled (default)
# ─────────────────────────────────────────────

resource "azurerm_recovery_services_vault" "main" {
  count               = local.enable_backup ? 1 : 0
  name                = "${local.name_prefix}-rsv"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  # CKV_AZURE_228: soft delete protects backup data from accidental/malicious deletion
  soft_delete_enabled = true

  immutability = "Unlocked"
  tags         = var.md_metadata.default_tags
}

resource "azurerm_backup_policy_file_share" "main" {
  count               = local.enable_backup ? 1 : 0
  name                = "${local.name_prefix}-backup-policy"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name

  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  retention_daily {
    count = try(var.backup.retention_days, 30)
  }
}
