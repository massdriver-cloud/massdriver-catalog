# Checkov CKV2_AZURE_31 requires a network security group on every subnet.
# Each subnet gets its own group. The default rules of Azure allow traffic
# inside the network and deny inbound traffic from the internet.

resource "azurerm_network_security_group" "main" {
  for_each = local.subnets

  name                = "${local.name_prefix}-${each.value.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.md_metadata.default_tags
}

resource "azurerm_subnet_network_security_group_association" "main" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.main[each.key].id
  network_security_group_id = azurerm_network_security_group.main[each.key].id
}
