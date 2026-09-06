# Starting points, not a monitoring strategy. Errors and refusals are always
# someone's problem; duration is here because a function that creeps toward its
# timeout fails all at once, with no warning, on the busiest day.

resource "massdriver_instance_alarm" "errors" {
  display_name        = "Endpoint throwing errors"
  cloud_resource_id   = "${aws_lambda_function.main.arn}:errors"
  threshold           = 5
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

# Requests refused because the ceiling was reached. Either real traffic has
# outgrown the limit, or something is calling this in a loop.
resource "massdriver_instance_alarm" "throttles" {
  display_name        = "Requests refused at the limit"
  cloud_resource_id   = "${aws_lambda_function.main.arn}:throttles"
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

# Fires at 80% of the configured timeout, in milliseconds, so there is room to
# act before requests start being cut off.
resource "massdriver_instance_alarm" "approaching_timeout" {
  display_name        = "Requests approaching the timeout"
  cloud_resource_id   = "${aws_lambda_function.main.arn}:duration"
  threshold           = var.timeout_seconds * 1000 * 0.8
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "Duration"
    namespace = "AWS/Lambda"
    statistic = "p99"
    dimensions = {
      FunctionName = aws_lambda_function.main.function_name
    }
  }
}
