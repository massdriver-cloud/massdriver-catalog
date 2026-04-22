# ─── BigQuery Subscription (optional) ─────────────────────────────────────────
#
# This file is count-gated on var.pubsub_topic being non-null.
# When a Pub/Sub topic is wired on the canvas, three resources are created:
#
# 1. google_bigquery_table_iam_member.pubsub_service_agent_data_editor
# 2. google_bigquery_table_iam_member.pubsub_service_agent_metadata_viewer
# 3. google_pubsub_subscription.bigquery
#
# IAM bindings grant the Pub/Sub service agent
# (service-<project-num>@gcp-sa-pubsub.iam.gserviceaccount.com) the minimum
# roles required to write messages into the BigQuery table. Bindings are
# table-scoped, not dataset- or project-wide.

# ─── Pub/Sub service agent project number ──────────────────────────────────────
# The Pub/Sub service agent SA is project-number-scoped, so we need the numeric
# project number to construct the identity.
data "google_project" "this" {
  project_id = local.project_id
}

locals {
  pubsub_enabled         = var.pubsub_topic != null
  pubsub_service_account = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  # BigQuery subscription table reference format: projectId:datasetId.tableId
  # This is the format required by the Pub/Sub API and the Terraform provider.
  bq_table_ref = local.pubsub_enabled ? "${local.project_id}:${local.dataset_id}.${var.table_id}" : null
}

# ─── IAM: dataEditor on this table ────────────────────────────────────────────
# Required so the Pub/Sub service agent can INSERT rows into the target table.
# Scoped to this specific table — not the full dataset — for least privilege.
resource "google_bigquery_table_iam_member" "pubsub_service_agent_data_editor" {
  count = local.pubsub_enabled ? 1 : 0

  project    = local.project_id
  dataset_id = local.dataset_id
  table_id   = google_bigquery_table.main.table_id
  role       = "roles/bigquery.dataEditor"
  member     = local.pubsub_service_account
}

# ─── IAM: metadataViewer on this table ────────────────────────────────────────
# Required so the Pub/Sub service agent can read the table schema and validate
# message delivery configuration. Scoped to this specific table.
resource "google_bigquery_table_iam_member" "pubsub_service_agent_metadata_viewer" {
  count = local.pubsub_enabled ? 1 : 0

  project    = local.project_id
  dataset_id = local.dataset_id
  table_id   = google_bigquery_table.main.table_id
  role       = "roles/bigquery.metadataViewer"
  member     = local.pubsub_service_account
}

# ─── Pub/Sub subscription with BigQuery delivery ───────────────────────────────
resource "google_pubsub_subscription" "bigquery" {
  count = local.pubsub_enabled ? 1 : 0

  project = var.pubsub_topic.project_id
  name    = local.subscription_name
  topic   = var.pubsub_topic.topic_id

  ack_deadline_seconds = var.bigquery_subscription.ack_deadline_seconds

  bigquery_config {
    table               = local.bq_table_ref
    use_topic_schema    = var.bigquery_subscription.use_topic_schema
    write_metadata      = var.bigquery_subscription.write_metadata
    drop_unknown_fields = var.bigquery_subscription.drop_unknown_fields
  }

  labels = var.md_metadata.default_tags

  # The table and IAM bindings must exist before Pub/Sub validates the subscription.
  # Without the IAM bindings, Pub/Sub cannot write to BigQuery.
  # IAM propagation is eventually consistent — depends_on mitigates but does not
  # eliminate timing issues. If the subscription fails, a redeploy resolves it.
  depends_on = [
    google_bigquery_table_iam_member.pubsub_service_agent_data_editor,
    google_bigquery_table_iam_member.pubsub_service_agent_metadata_viewer,
  ]
}
