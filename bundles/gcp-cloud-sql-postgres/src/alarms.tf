# Alarms fire into Massdriver rather than into a mailbox somebody stops reading.
# The webhook is generated per instance, so an alert arrives already attached to the
# component that raised it.
resource "google_monitoring_notification_channel" "massdriver" {
  display_name = "Massdriver ${var.md_metadata.name_prefix}"
  type         = "webhook_tokenauth"

  labels = {
    url = var.md_metadata.observability.alarm_webhook_url
  }
}

locals {
  instance_filter = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${var.gcp_service_account.project_id}:${google_sql_database_instance.main.name}\""

  # Three things worth being woken for on a database every app shares. Disk is first
  # because a full disk is the one that takes everything down at once and the one you
  # get the most warning about.
  alarms = {
    disk = {
      display   = "Disk almost full"
      metric    = "cloudsql.googleapis.com/database/disk/utilization"
      threshold = 0.85
      duration  = "300s"
      aligner   = "ALIGN_MEAN"
    }
    cpu = {
      display   = "CPU pinned"
      metric    = "cloudsql.googleapis.com/database/cpu/utilization"
      threshold = 0.9
      duration  = "600s"
      aligner   = "ALIGN_MEAN"
    }
    memory = {
      display   = "Memory almost exhausted"
      metric    = "cloudsql.googleapis.com/database/memory/utilization"
      threshold = 0.9
      duration  = "600s"
      aligner   = "ALIGN_MEAN"
    }
  }
}

resource "google_monitoring_alert_policy" "db" {
  for_each = local.alarms

  display_name          = "${var.md_metadata.name_prefix} — ${each.value.display}"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.massdriver.name]

  conditions {
    display_name = each.value.display

    condition_threshold {
      filter          = "${local.instance_filter} AND metric.type = \"${each.value.metric}\""
      comparison      = "COMPARISON_GT"
      threshold_value = each.value.threshold
      duration        = each.value.duration

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = each.value.aligner
      }

      trigger { count = 1 }
    }
  }

  # Without this an alarm that fires once stays open forever, and the next real
  # incident is invisible underneath it.
  alert_strategy {
    auto_close = "3600s"
  }
}

# The alert policy above lives in GCP. This is what tells Massdriver the alarm
# exists, so it shows on the instance and an alert lands against the component
# that raised it rather than in a webhook log nobody reads.
resource "massdriver_instance_alarm" "db" {
  for_each = local.alarms

  display_name        = each.value.display
  cloud_resource_id   = google_monitoring_alert_policy.db[each.key].name
  comparison_operator = "greater_than"
  threshold           = each.value.threshold
  period              = 300

  metric {
    namespace  = "cloudsql.googleapis.com/database"
    name       = each.value.metric
    statistic  = "average"
    region     = var.region
    dimensions = {}
  }
}
