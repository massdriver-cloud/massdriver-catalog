resource "massdriver_artifact" "azure_virtual_network" {
  field = "azure_virtual_network"
  name  = "Azure VNet ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id                  = azurerm_virtual_network.main.id
    resource_group_name = azurerm_resource_group.main.name
    location            = azurerm_virtual_network.main.location
    cidr                = var.cidr
    subnets = [
      for name, subnet in azurerm_subnet.main : {
        id   = subnet.id
        name = subnet.name
        cidr = subnet.address_prefixes[0]
      }
    ]
  })
}
