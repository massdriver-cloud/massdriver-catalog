# Azure Monitor metrics for a container app.

resource "massdriver_instance_alarm" "restarts" {
  display_name        = "Container restarts"
  cloud_resource_id   = "${azurerm_container_app.main.id}|restarts"
  threshold           = 3
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "RestartCount"
    namespace = "Microsoft.App/containerApps"
    statistic = "Total"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "replicas" {
  display_name        = "No running replica"
  cloud_resource_id   = "${azurerm_container_app.main.id}|replicas"
  threshold           = 1
  period              = 300
  comparison_operator = "LessThanThreshold"

  metric {
    name      = "Replicas"
    namespace = "Microsoft.App/containerApps"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "memory" {
  display_name        = "Memory above 90 percent of the limit"
  cloud_resource_id   = "${azurerm_container_app.main.id}|memory"
  threshold           = 90
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "WorkingSetBytes"
    namespace = "Microsoft.App/containerApps"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}
