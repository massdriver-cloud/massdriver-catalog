# Azure Monitor metrics for a managed cluster.

resource "massdriver_instance_alarm" "node_not_ready" {
  display_name        = "A node is not ready"
  cloud_resource_id   = "${azurerm_kubernetes_cluster.main.id}|node_not_ready"
  threshold           = 0
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "kube_node_status_condition"
    namespace = "Microsoft.ContainerService/managedClusters"
    statistic = "Total"
    region    = azurerm_resource_group.main.location

    dimensions = {
      condition = "Ready"
      status    = "false"
    }
  }
}

resource "massdriver_instance_alarm" "cpu" {
  display_name        = "Node processor above 85 percent"
  cloud_resource_id   = "${azurerm_kubernetes_cluster.main.id}|cpu"
  threshold           = 85
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "node_cpu_usage_percentage"
    namespace = "Microsoft.ContainerService/managedClusters"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "memory" {
  display_name        = "Node memory above 90 percent"
  cloud_resource_id   = "${azurerm_kubernetes_cluster.main.id}|memory"
  threshold           = 90
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "node_memory_working_set_percentage"
    namespace = "Microsoft.ContainerService/managedClusters"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "pods_not_running" {
  display_name        = "Pods not in the running phase"
  cloud_resource_id   = "${azurerm_kubernetes_cluster.main.id}|pods_not_running"
  threshold           = 3
  period              = 600
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "kube_pod_status_phase"
    namespace = "Microsoft.ContainerService/managedClusters"
    statistic = "Average"
    region    = azurerm_resource_group.main.location

    dimensions = {
      phase = "Failed"
    }
  }
}
