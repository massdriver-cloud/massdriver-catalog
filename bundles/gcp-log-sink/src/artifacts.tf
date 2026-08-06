# Log sink artifact — matches catalog-demo/gcp-log-sink schema.

resource "massdriver_artifact" "log_sink" {
  field = "log_sink"
  name  = "GCP Log Sink ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id       = local.project_id
    sink_name        = google_logging_project_sink.main.name
    destination      = google_logging_project_sink.main.destination
    writer_identity  = google_logging_project_sink.main.writer_identity
    destination_type = local.destination_type
  })
}
