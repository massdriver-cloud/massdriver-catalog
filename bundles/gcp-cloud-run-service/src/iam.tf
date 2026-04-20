# ─── Upstream Artifact IAM Auto-Binding ───────────────────────────────────────
#
# This file implements the "auto-binding" pattern for Cloud Run services that
# consume upstream data artifacts. For each optional connection that IS wired on
# the canvas, Terraform grants the workload service account the minimum-privilege
# role required to use that resource.
#
# HOW IT WORKS
# ────────────
# Massdriver passes optional connections as null when not wired on the canvas,
# or as a plain object when wired. We detect presence with: var.<connection> != null
# Then use `count = var.<connection> != null ? 1 : 0` to conditionally create
# the binding. No connection → no IAM change. Add connection → binding appears
# on next deploy. Remove connection → binding is destroyed on next deploy.
#
# ROLES GRANTED
# ─────────────
# Pub/Sub topic   → roles/pubsub.publisher
#   Allows the service to publish messages to the topic. Does NOT grant
#   subscription creation or management. For subscriber access, use a separate
#   binding with roles/pubsub.subscriber.
#
# BigQuery dataset → roles/bigquery.dataEditor
#   Allows reading, writing, and deleting table data, and creating/deleting
#   tables within the dataset. Does NOT allow dropping the dataset itself.
#   For read-only access, use roles/bigquery.dataViewer instead.
#
# Storage bucket   → roles/storage.objectUser
#   Allows reading and writing objects (get, list, create, delete). Does NOT
#   grant bucket-level admin (lifecycle, IAM, metadata changes). For read-only
#   access, use roles/storage.objectViewer instead.
#
# REFERENCE EXAMPLE
# ─────────────────
# This is the canonical artifact-policy-style auto-binding pattern for the
# GCP Data Platform demo series. When building downstream bundles that consume
# multiple optional artifacts, copy this pattern: one conditional count block
# per artifact type, one role per binding, all referencing local.workload_sa_member.

# ── Pub/Sub Topic ─────────────────────────────────────────────────────────────
# Grant the workload SA publisher access to the connected Pub/Sub topic.
# Binding is topic-scoped — does not grant access to other topics.

resource "google_pubsub_topic_iam_member" "workload_publisher" {
  count = var.pubsub_topic != null ? 1 : 0

  project = var.pubsub_topic.project_id
  topic   = var.pubsub_topic.topic_name
  role    = "roles/pubsub.publisher"
  member  = local.workload_sa_member
}

# ── BigQuery Dataset ───────────────────────────────────────────────────────────
# Grant the workload SA dataEditor on the connected BigQuery dataset.
# Binding is dataset-scoped — propagates to all current and future tables in
# the dataset. For table-level isolation, use google_bigquery_table_iam_member.

resource "google_bigquery_dataset_iam_member" "workload_data_editor" {
  count = var.bigquery_dataset != null ? 1 : 0

  project    = var.bigquery_dataset.project_id
  dataset_id = var.bigquery_dataset.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = local.workload_sa_member
}

# ── Storage Bucket ─────────────────────────────────────────────────────────────
# Grant the workload SA objectUser on the connected GCS bucket.
# Binding is bucket-scoped — allows read/write of all objects in the bucket.
# For read-only access, use roles/storage.objectViewer.

resource "google_storage_bucket_iam_member" "workload_object_user" {
  count = var.storage_bucket != null ? 1 : 0

  bucket = var.storage_bucket.bucket_name
  role   = "roles/storage.objectUser"
  member = local.workload_sa_member
}
