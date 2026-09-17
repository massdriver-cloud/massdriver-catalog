locals {
  name_prefix = var.md_metadata.name_prefix

  # An App Service plan joins a subnet that carries the App Service delegation.
  delegated_subnets = [
    for subnet in var.network.subnets : subnet
    if try(subnet.delegation, "") == "appservice"
  ]

  subnet_id = try(local.delegated_subnets[0].id, null)

  has_database = try(var.database.auth.hostname, null) != null
  has_bucket   = try(var.bucket.name, null) != null

  app_settings = merge(
    {
      LOG_LEVEL                   = var.log_level
      PORT                        = tostring(var.port)
      WEBSITES_PORT               = tostring(var.port)
      WEBSITES_CONTAINER_START_TIME_LIMIT = "300"
    },
    local.has_database ? {
      DATABASE_HOST     = var.database.auth.hostname
      DATABASE_PORT     = tostring(var.database.auth.port)
      DATABASE_NAME     = var.database.auth.database
      DATABASE_USER     = var.database.auth.username
      DATABASE_PASSWORD = var.database.auth.password
    } : {},
    local.has_bucket ? {
      STORAGE_ACCOUNT   = var.bucket.name
      STORAGE_CONTAINER = var.bucket.container
      STORAGE_ENDPOINT  = var.bucket.endpoint
      STORAGE_POLICY    = try(var.bucket_policy, "")
    } : {}
  )
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_service_plan" "main" {
  lifecycle {
    precondition {
      condition     = local.subnet_id != null
      error_message = "The connected network holds no subnet with the App Service delegation. Add one, then deploy again."
    }
  }

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.plan_sku
  worker_count        = var.instance_count
  tags                = var.md_metadata.default_tags
}

resource "azurerm_linux_web_app" "main" {
  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  tags                = var.md_metadata.default_tags

  https_only                    = true
  public_network_access_enabled = true
  virtual_network_subnet_id     = local.subnet_id

  identity {
    type = "SystemAssigned"
  }

  app_settings = local.app_settings

  site_config {
    always_on              = var.always_on
    health_check_path      = var.health_check_path
    ftps_state             = "Disabled"
    minimum_tls_version    = "1.2"
    vnet_route_all_enabled = true

    application_stack {
      docker_image_name   = var.image
      docker_registry_url = "https://mcr.microsoft.com"
    }
  }
}

resource "azurerm_role_assignment" "bucket" {
  count = local.has_bucket && try(var.bucket_policy, "") != "" ? 1 : 0

  scope                = var.bucket.id
  role_definition_name = var.bucket_policy
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
