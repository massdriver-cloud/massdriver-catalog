# Registered with Massdriver's alarm system; thresholds surface on the
# instance's health panel in the UI.

locals {
  # Alarm when free storage drops below 20% of allocated storage, in bytes.
  storage_low_threshold_bytes = floor(var.allocated_storage_gb * 0.2 * 1073741824)
}

resource "massdriver_instance_alarm" "high_connections" {
  display_name        = "High Connections"
  cloud_resource_id   = aws_db_instance.main.arn
  threshold           = 80
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "DatabaseConnections"
    namespace = "AWS/RDS"
    statistic = "Average"
    dimensions = {
      DBInstanceIdentifier = aws_db_instance.main.identifier
    }
  }
}

resource "massdriver_instance_alarm" "cpu_high" {
  display_name        = "CPU High"
  cloud_resource_id   = aws_db_instance.main.arn
  threshold           = 90
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "CPUUtilization"
    namespace = "AWS/RDS"
    statistic = "Average"
    dimensions = {
      DBInstanceIdentifier = aws_db_instance.main.identifier
    }
  }
}

resource "massdriver_instance_alarm" "storage_low" {
  display_name        = "Storage Low"
  cloud_resource_id   = aws_db_instance.main.arn
  threshold           = local.storage_low_threshold_bytes
  period              = 300
  comparison_operator = "LessThanThreshold"

  metric {
    name      = "FreeStorageSpace"
    namespace = "AWS/RDS"
    statistic = "Average"
    dimensions = {
      DBInstanceIdentifier = aws_db_instance.main.identifier
    }
  }
}

resource "massdriver_instance_alarm" "replication_lag" {
  count = var.high_availability ? 1 : 0

  display_name        = "Replication Lag"
  cloud_resource_id   = aws_db_instance.main.arn
  threshold           = 30
  period              = 300
  comparison_operator = "GreaterThanThreshold"

  metric {
    name      = "ReplicaLag"
    namespace = "AWS/RDS"
    statistic = "Average"
    dimensions = {
      DBInstanceIdentifier = aws_db_instance.main.identifier
    }
  }
}
