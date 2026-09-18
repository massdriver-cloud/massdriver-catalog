resource "massdriver_resource" "network" {
  field = "network"
  name  = "Virtual Network ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id             = azurerm_virtual_network.main.id
    name           = azurerm_virtual_network.main.name
    cidr           = local.cidr
    region         = var.region
    account_id     = var.azure_service_principal.subscription_id
    resource_group = azurerm_resource_group.main.name
    dns_servers    = var.dns_servers
    subnets = [
      for name, subnet in azurerm_subnet.main : {
        id         = subnet.id
        name       = subnet.name
        cidr       = subnet.address_prefixes[0]
        delegation = local.subnets[name].delegation
      }
    ]
  })
}
