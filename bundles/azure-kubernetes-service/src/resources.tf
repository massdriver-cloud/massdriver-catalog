locals {
  kube = azurerm_kubernetes_cluster.main.kube_config[0]
}

resource "massdriver_resource" "cluster" {
  field = "cluster"
  name  = "Kubernetes ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id      = azurerm_kubernetes_cluster.main.id
    name    = azurerm_kubernetes_cluster.main.name
    region  = azurerm_resource_group.main.location
    version = azurerm_kubernetes_cluster.main.kubernetes_version

    authentication = {
      host                   = local.kube.host
      cluster_ca_certificate = local.kube.cluster_ca_certificate
      client_certificate     = local.kube.client_certificate
      client_key             = local.kube.client_key
    }
  })
}
