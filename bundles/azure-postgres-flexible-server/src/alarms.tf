# Azure Monitor metrics for a flexible server. Massdriver watches them and
# raises an alarm on the instance.

resource "massdriver_instance_alarm" "cpu" {
  display_name        = "CPU above 80 percent"
  cloud_resource_id   = "${azurerm_postgresql_flexible_server.main.id}|cpu"
  threshold           = 80
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "cpu_percent"
    namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "storage" {
  display_name        = "Disk above 85 percent"
  cloud_resource_id   = "${azurerm_postgresql_flexible_server.main.id}|storage"
  threshold           = 85
  period              = 600
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "storage_percent"
    namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "connections" {
  display_name        = "Connections above 80 percent of the limit"
  cloud_resource_id   = "${azurerm_postgresql_flexible_server.main.id}|connections"
  threshold           = 80
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "connections_percentage"
    namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}
