# Azure Monitor metrics for a Data Factory.

resource "massdriver_instance_alarm" "failed_pipelines" {
  display_name        = "Failed pipeline runs"
  cloud_resource_id   = "${azurerm_data_factory.main.id}|failed_pipelines"
  threshold           = 0
  period              = 900
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "PipelineFailedRuns"
    namespace = "Microsoft.DataFactory/factories"
    statistic = "Total"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "failed_activities" {
  display_name        = "Failed activity runs"
  cloud_resource_id   = "${azurerm_data_factory.main.id}|failed_activities"
  threshold           = 2
  period              = 900
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "ActivityFailedRuns"
    namespace = "Microsoft.DataFactory/factories"
    statistic = "Total"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "failed_triggers" {
  display_name        = "Failed trigger runs"
  cloud_resource_id   = "${azurerm_data_factory.main.id}|failed_triggers"
  threshold           = 0
  period              = 900
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "TriggerFailedRuns"
    namespace = "Microsoft.DataFactory/factories"
    statistic = "Total"
    region    = azurerm_resource_group.main.location
  }
}
