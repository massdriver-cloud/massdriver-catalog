# ─── Upstream Artifact IAM Auto-Binding ───────────────────────────────────────
#
# This file implements the "auto-binding" pattern for Cloud Run services that
# consume upstream data artifacts. For each optional connection that IS wired on
# the canvas, Terraform grants THIS bundle's runtime service account the minimum-
# privilege role required to use that resource.
#
# The runtime SA (google_service_account.runtime in main.tf) is created by this
# bundle — not inherited from the landing zone. This means each Cloud Run service
# gets its own identity with bindings only to the resources it actually connects to.
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

# ── Pub/Sub Topic ─────────────────────────────────────────────────────────────
# Grant this service's runtime SA publisher access to the connected Pub/Sub topic.
# Binding is topic-scoped — does not grant access to other topics.

resource "google_pubsub_topic_iam_member" "runtime_publisher" {
  count = var.pubsub_topic != null ? 1 : 0

  project = var.pubsub_topic.project_id
  topic   = var.pubsub_topic.topic_name
  role    = "roles/pubsub.publisher"
  member  = local.runtime_sa_member
}

# ── BigQuery Dataset ───────────────────────────────────────────────────────────
# Grant this service's runtime SA dataEditor on the connected BigQuery dataset.
# Binding is dataset-scoped — propagates to all current and future tables in
# the dataset. For table-level isolation, use google_bigquery_table_iam_member.

resource "google_bigquery_dataset_iam_member" "runtime_data_editor" {
  count = var.bigquery_dataset != null ? 1 : 0

  project    = var.bigquery_dataset.project_id
  dataset_id = var.bigquery_dataset.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = local.runtime_sa_member
}

# ── Storage Bucket ─────────────────────────────────────────────────────────────
# Grant this service's runtime SA objectUser on the connected GCS bucket.
# Binding is bucket-scoped — allows read/write of all objects in the bucket.
# For read-only access, use roles/storage.objectViewer.

resource "google_storage_bucket_iam_member" "runtime_object_user" {
  count = var.storage_bucket != null ? 1 : 0

  bucket = var.storage_bucket.bucket_name
  role   = "roles/storage.objectUser"
  member = local.runtime_sa_member
}
