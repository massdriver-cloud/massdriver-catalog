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
  service_filter = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${google_cloud_run_v2_service.app.name}\""
}

# Any 5xx at all. A citizen app serving errors is worth a look even at low volume,
# because the people who own it are not watching a dashboard.
resource "google_monitoring_alert_policy" "errors" {
  display_name          = "${var.md_metadata.name_prefix} — Serving errors"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.massdriver.name]

  conditions {
    display_name = "5xx responses"

    condition_threshold {
      filter          = "${local.service_filter} AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "300s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger { count = 1 }
    }
  }

  alert_strategy { auto_close = "3600s" }
}

# Slow responses, measured at the 95th percentile so one cold start does not page
# anybody. Cloud Run reports latency in milliseconds.
resource "google_monitoring_alert_policy" "latency" {
  display_name          = "${var.md_metadata.name_prefix} — Slow responses"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.massdriver.name]

  conditions {
    display_name = "95th percentile over 5 seconds"

    condition_threshold {
      filter          = "${local.service_filter} AND metric.type = \"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5000
      duration        = "300s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
      }

      trigger { count = 1 }
    }
  }

  alert_strategy { auto_close = "3600s" }
}

# The alert policies above live in GCP. These are what tell Massdriver the alarms
# exist, so they show on the instance and an alert lands against the component that
# raised it rather than in a webhook log nobody reads.
resource "massdriver_instance_alarm" "errors" {
  display_name        = "Serving errors"
  cloud_resource_id   = google_monitoring_alert_policy.errors.name
  comparison_operator = "greater_than"
  threshold           = 0
  period              = 300

  metric {
    namespace  = "run.googleapis.com"
    name       = "request_count"
    statistic  = "sum"
    region     = var.region
    dimensions = { response_code_class = "5xx" }
  }
}

resource "massdriver_instance_alarm" "latency" {
  display_name        = "Slow responses"
  cloud_resource_id   = google_monitoring_alert_policy.latency.name
  comparison_operator = "greater_than"
  threshold           = 5000
  period              = 300

  metric {
    namespace  = "run.googleapis.com"
    name       = "request_latencies"
    statistic  = "p95"
    region     = var.region
    dimensions = {}
  }
}
