locals {
  name_prefix     = var.md_metadata.name_prefix
  subscription_id = "/subscriptions/${var.azure_service_principal.subscription_id}"
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  tags                = var.md_metadata.default_tags
}

# Every control plane action on the subscription lands in the workspace. An
# auditor reads this record.
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  count = var.activity_log_enabled ? 1 : 0

  name                       = "${local.name_prefix}-activity"
  target_resource_id         = local.subscription_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Policy"
  }

  enabled_log {
    category = "Alert"
  }
}

resource "azurerm_security_center_subscription_pricing" "main" {
  tier          = var.defender_plan
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_contact" "main" {
  count = var.security_contact_email != "" ? 1 : 0

  name                = "default"
  email               = var.security_contact_email
  alert_notifications = true
  alerts_to_admins    = true
}
