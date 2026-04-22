# ─── BigQuery Subscription (optional) ─────────────────────────────────────────
#
# This file is count-gated on var.pubsub_topic being non-null.
# When a Pub/Sub topic is wired on the canvas, three resources are created:
#
# 1. google_bigquery_dataset_iam_member.pubsub_service_agent_data_editor
# 2. google_bigquery_dataset_iam_member.pubsub_service_agent_metadata_viewer
# 3. google_pubsub_subscription.bigquery
#
# IAM bindings grant the Pub/Sub service agent
# (service-<project-num>@gcp-sa-pubsub.iam.gserviceaccount.com) the minimum
# roles required to write messages into BigQuery. Bindings are dataset-scoped,
# not project-wide.
#
# IMPORTANT — the target table must exist before deployment.
# Pub/Sub does NOT create BigQuery tables. Create the table in the dataset
# (manually, via a companion bundle, or via Dataform) before wiring this
# connection. Deploying when the table is absent will succeed at the Terraform
# layer but the subscription will fail to deliver and messages will back up.

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
  bq_table_ref = local.pubsub_enabled ? "${local.project_id}:${local.dataset_id}.${var.bigquery_subscription.table_name}" : null

  # Subscription name derived from the bundle name prefix for uniqueness.
  subscription_name = "${local.name_prefix}-bq"
}

# ─── IAM: dataEditor on this dataset ──────────────────────────────────────────
# Required so the Pub/Sub service agent can INSERT rows into the target table.
resource "google_bigquery_dataset_iam_member" "pubsub_service_agent_data_editor" {
  count = local.pubsub_enabled ? 1 : 0

  project    = local.project_id
  dataset_id = google_bigquery_dataset.main.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = local.pubsub_service_account
}

# ─── IAM: metadataViewer on this dataset ──────────────────────────────────────
# Required so the Pub/Sub service agent can read table schemas and dataset
# metadata to validate message delivery configuration.
resource "google_bigquery_dataset_iam_member" "pubsub_service_agent_metadata_viewer" {
  count = local.pubsub_enabled ? 1 : 0

  project    = local.project_id
  dataset_id = google_bigquery_dataset.main.dataset_id
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

  # The IAM bindings must exist before Pub/Sub validates the subscription's
  # ability to write to BigQuery. Without these, the subscription creation will
  # fail with a permission error even though the resource itself is valid.
  depends_on = [
    google_bigquery_dataset_iam_member.pubsub_service_agent_data_editor,
    google_bigquery_dataset_iam_member.pubsub_service_agent_metadata_viewer,
  ]
}
