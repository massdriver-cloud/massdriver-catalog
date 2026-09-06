# Starting points, not a monitoring strategy. Server errors and latency are
# always the platform's problem; client errors usually are not, which is why
# only a sustained flood of them is worth waking someone for.

# The application is failing, not the caller. Any of these is a real user
# hitting a real error.
resource "massdriver_instance_alarm" "server_errors" {
  display_name        = "Requests failing"
  cloud_resource_id   = "${aws_apigatewayv2_api.main.arn}:5xx"
  threshold           = 5
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "5xx"
    namespace = "AWS/ApiGateway"
    statistic = "Sum"
    dimensions = {
      ApiId = aws_apigatewayv2_api.main.id
    }
  }
}

# A steady trickle of these is normal — bad paths, expired sign-ins, someone
# poking at the address. A flood is not, and usually means a deploy changed a
# route out from under a client, or a sign-in policy is rejecting people it
# should be letting through.
resource "massdriver_instance_alarm" "client_errors" {
  display_name        = "Callers being turned away"
  cloud_resource_id   = "${aws_apigatewayv2_api.main.arn}:4xx"
  threshold           = 100
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "4xx"
    namespace = "AWS/ApiGateway"
    statistic = "Sum"
    dimensions = {
      ApiId = aws_apigatewayv2_api.main.id
    }
  }
}

# Measured at the 99th percentile rather than the average, because an average
# stays comfortable while the slowest requests time out.
resource "massdriver_instance_alarm" "slow_responses" {
  display_name        = "Slowest requests getting slow"
  cloud_resource_id   = "${aws_apigatewayv2_api.main.arn}:latency"
  threshold           = 3000
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "Latency"
    namespace = "AWS/ApiGateway"
    statistic = "p99"
    dimensions = {
      ApiId = aws_apigatewayv2_api.main.id
    }
  }
}
