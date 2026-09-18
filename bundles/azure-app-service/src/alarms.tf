# Azure Monitor metrics for a web application.

resource "massdriver_instance_alarm" "server_errors" {
  display_name        = "Server errors in five minutes"
  cloud_resource_id   = "${azurerm_linux_web_app.main.id}|server_errors"
  threshold           = 5
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "Http5xx"
    namespace = "Microsoft.Web/sites"
    statistic = "Total"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "response_time" {
  display_name        = "Response time above three seconds"
  cloud_resource_id   = "${azurerm_linux_web_app.main.id}|response_time"
  threshold           = 3
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "HttpResponseTime"
    namespace = "Microsoft.Web/sites"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}

resource "massdriver_instance_alarm" "health_check" {
  display_name        = "Health check below 100 percent"
  cloud_resource_id   = "${azurerm_linux_web_app.main.id}|health_check"
  threshold           = 100
  period              = 300
  comparison_operator = "LessThanThreshold"

  metric {
    name      = "HealthCheckStatus"
    namespace = "Microsoft.Web/sites"
    statistic = "Average"
    region    = azurerm_resource_group.main.location
  }
}
