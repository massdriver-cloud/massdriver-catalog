locals {
  name_prefix = var.md_metadata.name_prefix

  # A cluster needs a subnet that no service owns. The network bundle marks such
  # a subnet with the delegation `none`.
  open_subnets = [
    for subnet in var.network.subnets : subnet
    if try(subnet.delegation, "none") == "none"
  ]

  subnet_id = try(local.open_subnets[0].id, null)
}

resource "azurerm_resource_group" "main" {
  name     = local.name_prefix
  location = var.network.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_kubernetes_cluster" "main" {
  lifecycle {
    precondition {
      condition     = local.subnet_id != null
      error_message = "The connected network holds no subnet without a delegation. Add one, then deploy again."
    }

    precondition {
      condition     = var.max_nodes >= var.min_nodes
      error_message = "The maximum node count is lower than the minimum. Correct one of the two values."
    }
  }

  name                = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = local.name_prefix
  tags                = var.md_metadata.default_tags

  kubernetes_version      = var.kubernetes_version
  sku_tier                = var.service_tier
  private_cluster_enabled = var.private_cluster
  local_account_disabled  = false

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_size
    vnet_subnet_id       = local.subnet_id
    auto_scaling_enabled = true
    min_count            = var.min_nodes
    max_count            = var.max_nodes
    os_disk_size_gb      = 64
    max_pods             = 30
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }
}
