# Stand-in alarms registered with Massdriver. Replace `cloud_resource_id` with
# the real CloudWatch / Azure Monitor / GCP Monitoring identifier when this
# bundle deploys real infrastructure.

resource "massdriver_instance_alarm" "slow_query_rate" {
  count = var.slow_query_log_enabled ? 1 : 0

  display_name        = "Slow Query Rate"
  cloud_resource_id   = "demo:mysql:${random_pet.main.id}:slow-queries"
  threshold           = 50
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "SlowQueries"
    namespace = "Demo/MySQL"
    statistic = "Sum"
    dimensions = {
      DBInstanceIdentifier = random_pet.main.id
    }
  }
}

resource "massdriver_instance_alarm" "replication_lag" {
  count = var.high_availability ? 1 : 0

  display_name        = "Replication Lag"
  cloud_resource_id   = "demo:mysql:${random_pet.main.id}:replication-lag"
  threshold           = 30
  period              = 60
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "ReplicaLagInSeconds"
    namespace = "Demo/MySQL"
    statistic = "Maximum"
    dimensions = {
      DBInstanceIdentifier = random_pet.main.id
    }
  }
}

resource "massdriver_instance_alarm" "storage_eighty_percent_full" {
  display_name        = "Storage 80% Full"
  cloud_resource_id   = "demo:mysql:${random_pet.main.id}:storage"
  threshold           = 80
  period              = 600
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "DiskUtilizationPercent"
    namespace = "Demo/MySQL"
    statistic = "Maximum"
    dimensions = {
      DBInstanceIdentifier = random_pet.main.id
    }
  }
}
