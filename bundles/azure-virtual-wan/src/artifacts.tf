locals {
  # Build the artifact object without vpn_gateway_id when no gateway is provisioned.
  # The artifact definition marks vpn_gateway_id as optional (not in required[]) but
  # uses type: string — passing null causes a validation error, so we omit the key
  # entirely when the VPN gateway is disabled.
  _artifact_base = {
    id                         = azurerm_virtual_wan.main.id
    resource_group_name        = azurerm_resource_group.main.name
    location                   = azurerm_virtual_wan.main.location
    virtual_hub_id             = azurerm_virtual_hub.main.id
    virtual_hub_address_prefix = var.hub_address_prefix
  }
  _artifact_vpn = var.enable_vpn_gateway ? {
    vpn_gateway_id = azurerm_vpn_gateway.main[0].id
  } : {}

  artifact_data = merge(local._artifact_base, local._artifact_vpn)
}

resource "massdriver_artifact" "azure_virtual_wan" {
  field    = "azure_virtual_wan"
  name     = "Azure Virtual WAN ${var.md_metadata.name_prefix}"
  artifact = jsonencode(local.artifact_data)
}
