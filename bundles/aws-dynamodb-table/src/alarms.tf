# Starting points, not a monitoring strategy. They fire on the two things that
# are always someone's problem — requests being refused, and the service itself
# failing — and stay quiet about the things that are usually the application's
# own doing.

# Requests refused because the table could not keep up. On demand absorbs most
# spikes but not an instant one, and provisioned refuses anything over what was
# reserved. Either way the application saw an error the user probably did too.
resource "massdriver_instance_alarm" "throttled_requests" {
  display_name        = "Requests being refused"
  cloud_resource_id   = "${aws_dynamodb_table.main.arn}:throttles"
  threshold           = 5
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "ThrottledRequests"
    namespace = "AWS/DynamoDB"
    statistic = "Sum"
    dimensions = {
      TableName = aws_dynamodb_table.main.name
    }
  }
}

# Errors on the AWS side rather than in the request. One is noise; a run of them
# means the table is not currently dependable and retries are not going to fix
# it.
resource "massdriver_instance_alarm" "system_errors" {
  display_name        = "Table returning errors"
  cloud_resource_id   = "${aws_dynamodb_table.main.arn}:system-errors"
  threshold           = 1
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "SystemErrors"
    namespace = "AWS/DynamoDB"
    statistic = "Sum"
    dimensions = {
      TableName = aws_dynamodb_table.main.name
    }
  }
}

# Only meaningful when capacity is reserved ahead of time. On demand has no
# ceiling to approach, so this would never fire and is not created.
resource "massdriver_instance_alarm" "read_capacity" {
  count = local.on_demand ? 0 : 1

  display_name        = "Reads near the reserved limit"
  cloud_resource_id   = "${aws_dynamodb_table.main.arn}:read-capacity"
  threshold           = var.read_capacity * 0.8 * 300
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "ConsumedReadCapacityUnits"
    namespace = "AWS/DynamoDB"
    statistic = "Sum"
    dimensions = {
      TableName = aws_dynamodb_table.main.name
    }
  }
}
