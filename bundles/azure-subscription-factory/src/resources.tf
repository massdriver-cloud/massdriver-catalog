resource "massdriver_resource" "account" {
  field = "account"
  name  = "Subscription ${var.subscription_name}"

  resource = jsonencode({
    id                 = azurerm_subscription.main.subscription_id
    name               = var.subscription_name
    landing_zone_class = var.landing_zone_class
    management_group   = var.management_group_id
    tenant_id          = var.azure_service_principal.tenant_id
    policy_assignments = local.policy_set
  })
}
