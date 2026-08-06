# Pub/Sub topic artifact — flat schema matching catalog-demo/gcp-pubsub-topic.
# Includes DLQ fields only when the DLQ is enabled (conditional merge).

resource "massdriver_artifact" "pubsub_topic" {
  field = "pubsub_topic"
  name  = "GCP Pub/Sub Topic ${var.md_metadata.name_prefix}"
  artifact = jsonencode(merge(
    {
      project_id = local.project_id
      topic_name = google_pubsub_topic.main.name
      topic_id   = google_pubsub_topic.main.id
    },
    var.dlq.enabled ? {
      dlq_topic_name = google_pubsub_topic.dlq[0].name
      dlq_topic_id   = google_pubsub_topic.dlq[0].id
    } : {}
  ))
}
