# Registered with Massdriver's alarm system; thresholds surface on the
# instance's health panel in the UI.

resource "massdriver_instance_alarm" "errors" {
  display_name        = "Errors"
  cloud_resource_id   = aws_lambda_function.main.arn
  threshold           = 1
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "Errors"
    namespace = "AWS/Lambda"
    statistic = "Sum"
    dimensions = {
      FunctionName = aws_lambda_function.main.function_name
    }
  }
}

resource "massdriver_instance_alarm" "throttles" {
  display_name        = "Throttles"
  cloud_resource_id   = aws_lambda_function.main.arn
  threshold           = 1
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "Throttles"
    namespace = "AWS/Lambda"
    statistic = "Sum"
    dimensions = {
      FunctionName = aws_lambda_function.main.function_name
    }
  }
}
