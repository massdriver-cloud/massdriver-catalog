# Azure Monitor metrics for a storage account.

resource "massdriver_instance_alarm" "availability" {
  display_name        = "Availability below 99 percent"
  cloud_resource_id   = "${azurerm_storage_account.main.id}|availability"
  threshold           = 99
  period              = 300
  comparison_operator = "LessThanThreshold"

  metric {
    name      = "Availability"
    namespace = "Microsoft.Storage/storageAccounts"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "server_errors" {
  display_name        = "Server errors in five minutes"
  cloud_resource_id   = "${azurerm_storage_account.main.id}|server_errors"
  threshold           = 5
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "Transactions"
    namespace = "Microsoft.Storage/storageAccounts"
    statistic = "Total"
    region    = azurerm_resource_group.main.location

    dimensions = {
      ResponseType = "ServerOtherError"
    }
  }
}

resource "massdriver_instance_alarm" "latency" {
  display_name        = "Write latency above one second"
  cloud_resource_id   = "${azurerm_storage_account.main.id}|latency"
  threshold           = 1000
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "SuccessE2ELatency"
    namespace = "Microsoft.Storage/storageAccounts"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}
