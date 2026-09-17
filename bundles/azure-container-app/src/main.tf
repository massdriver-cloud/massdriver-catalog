locals {
  name_prefix = var.md_metadata.name_prefix

  # Azure runs a Container Apps environment inside a subnet that carries the
  # Container Apps delegation. The subnet needs /23 or a larger range.
  delegated_subnets = [
    for subnet in var.network.subnets : subnet
    if try(subnet.delegation, "") == "containerapps"
  ]

  subnet_id = try(local.delegated_subnets[0].id, null)

  has_database = try(var.database.auth.hostname, null) != null
  has_bucket   = try(var.bucket.name, null) != null

  base_envs = {
    LOG_LEVEL         = var.log_level
    PORT              = tostring(var.port)
    HEALTH_CHECK_PATH = var.health_check_path
  }

  database_envs = local.has_database ? {
    DATABASE_HOST   = var.database.auth.hostname
    DATABASE_PORT   = tostring(var.database.auth.port)
    DATABASE_NAME   = var.database.auth.database
    DATABASE_USER   = var.database.auth.username
    DATABASE_POLICY = try(var.database_policy, "")
  } : {}

  bucket_envs = local.has_bucket ? {
    STORAGE_ACCOUNT   = var.bucket.name
    STORAGE_CONTAINER = var.bucket.container
    STORAGE_ENDPOINT  = var.bucket.endpoint
    STORAGE_POLICY    = try(var.bucket_policy, "")
  } : {}

  envs = merge(local.base_envs, local.database_envs, local.bucket_envs)
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.md_metadata.default_tags
}

resource "azurerm_container_app_environment" "main" {
  lifecycle {
    precondition {
      condition     = local.subnet_id != null
      error_message = "The connected network holds no subnet with the Container Apps delegation. Add one of /23 or larger, then deploy again."
    }
  }

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags

  infrastructure_subnet_id       = local.subnet_id
  internal_load_balancer_enabled = !var.public_ingress
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_container_app" "main" {
  name                         = local.name_prefix
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"
  tags                         = var.md_metadata.default_tags

  # The application reads the storage account with this identity. No access key
  # exists, so no secret can leak.
  identity {
    type = "SystemAssigned"
  }

  dynamic "secret" {
    for_each = local.has_database ? [1] : []

    content {
      name  = "database-password"
      value = var.database.auth.password
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "app"
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = local.envs

        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.has_database ? [1] : []

        content {
          name        = "DATABASE_PASSWORD"
          secret_name = "database-password"
        }
      }
    }
  }

  ingress {
    external_enabled = var.public_ingress
    target_port      = var.port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

# The application reads and writes the container with its own identity, at the
# access level that the developer selected.
resource "azurerm_role_assignment" "bucket" {
  count = local.has_bucket && try(var.bucket_policy, "") != "" ? 1 : 0

  scope                = var.bucket.id
  role_definition_name = var.bucket_policy
  principal_id         = azurerm_container_app.main.identity[0].principal_id
}
