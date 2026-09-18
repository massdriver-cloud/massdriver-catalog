# Azure Monitor metrics for a Cosmos DB account.

resource "massdriver_instance_alarm" "availability" {
  display_name        = "Availability below 99.99 percent"
  cloud_resource_id   = "${azurerm_cosmosdb_account.main.id}|availability"
  threshold           = 99.99
  period              = 300
  comparison_operator = "LessThanThreshold"

  metric {
    name      = "ServiceAvailability"
    namespace = "Microsoft.DocumentDB/databaseAccounts"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "throttled" {
  display_name        = "Throttled requests"
  cloud_resource_id   = "${azurerm_cosmosdb_account.main.id}|throttled"
  threshold           = 10
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "TotalRequests"
    namespace = "Microsoft.DocumentDB/databaseAccounts"
    statistic = "Total"
    region    = azurerm_resource_group.main.location

    dimensions = {
      StatusCode = "429"
    }
  }
}

resource "massdriver_instance_alarm" "request_units" {
  display_name        = "Request rate above 80 percent of the reserve"
  cloud_resource_id   = "${azurerm_cosmosdb_account.main.id}|request_units"
  threshold           = 80
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "NormalizedRUConsumption"
    namespace = "Microsoft.DocumentDB/databaseAccounts"
    statistic = "Maximum"
    region    = azurerm_resource_group.main.location
  }
}
