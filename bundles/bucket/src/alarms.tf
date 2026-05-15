# Stand-in alarms registered with Massdriver. Replace `cloud_resource_id` with
# the real CloudWatch / Azure Monitor / GCP Monitoring identifier when this
# bundle deploys real infrastructure.

resource "massdriver_instance_alarm" "five_xx_error_rate" {
  display_name        = "5xx Error Rate"
  cloud_resource_id   = "demo:bucket:${random_pet.main.id}:5xx"
  threshold           = 5
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "5xxErrors"
    namespace = "Demo/Bucket"
    statistic = "Sum"
    dimensions = {
      BucketName = local.bucket_name
    }
  }
}

resource "massdriver_instance_alarm" "anonymous_access_anomaly" {
  count = var.access_level == "private" ? 1 : 0

  display_name        = "Anonymous Access Anomaly"
  cloud_resource_id   = "demo:bucket:${random_pet.main.id}:anon-access"
  threshold           = 1
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "AnonymousRequests"
    namespace = "Demo/Bucket"
    statistic = "Sum"
    dimensions = {
      BucketName = local.bucket_name
    }
  }
}
