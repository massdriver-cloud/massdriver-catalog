# Azure Monitor metrics for a SQL database.

resource "massdriver_instance_alarm" "storage" {
  display_name        = "Storage above 85 percent"
  cloud_resource_id   = "${azurerm_mssql_database.main.id}|storage"
  threshold           = 85
  period              = 600
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "storage_percent"
    namespace = "Microsoft.Sql/servers/databases"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "cpu" {
  display_name        = "Processor above 80 percent"
  cloud_resource_id   = "${azurerm_mssql_database.main.id}|cpu"
  threshold           = 80
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "cpu_percent"
    namespace = "Microsoft.Sql/servers/databases"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "failed_connections" {
  display_name        = "Failed connections"
  cloud_resource_id   = "${azurerm_mssql_database.main.id}|failed_connections"
  threshold           = 10
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "connection_failed"
    namespace = "Microsoft.Sql/servers/databases"
    statistic = "Total"
    region    = azurerm_resource_group.main.location
  }
}
