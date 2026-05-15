# Stand-in alarms registered with Massdriver. Replace `cloud_resource_id` with
# the real CloudWatch / Azure Monitor / GCP Monitoring identifier (or
# Alertmanager rule URL) when this bundle deploys real infrastructure.

resource "massdriver_instance_alarm" "pod_restart_rate" {
  display_name        = "Pod Restart Rate"
  cloud_resource_id   = "demo:app:${random_pet.main.id}:pod-restarts"
  threshold           = 3
  period              = 600
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "PodRestarts"
    namespace = "Demo/Application"
    statistic = "Sum"
    dimensions = {
      ApplicationId = random_pet.main.id
    }
  }
}

resource "massdriver_instance_alarm" "five_xx_error_rate" {
  display_name        = "5xx Error Rate"
  cloud_resource_id   = "demo:app:${random_pet.main.id}:5xx"
  threshold           = 1
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "HTTP5xxRate"
    namespace = "Demo/Application"
    statistic = "Average"
    dimensions = {
      ApplicationId = random_pet.main.id
    }
  }
}

resource "massdriver_instance_alarm" "p95_latency" {
  display_name        = "p95 Latency (ms)"
  cloud_resource_id   = "demo:app:${random_pet.main.id}:p95-latency"
  threshold           = 500
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "RequestLatencyP95"
    namespace = "Demo/Application"
    statistic = "Maximum"
    dimensions = {
      ApplicationId = random_pet.main.id
    }
  }
}
