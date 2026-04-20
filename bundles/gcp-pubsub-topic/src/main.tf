terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

provider "google" {
  project     = var.gcp_authentication.project_id
  credentials = jsonencode(var.gcp_authentication)
}

locals {
  project_id  = var.landing_zone.project_id
  name_prefix = var.md_metadata.name_prefix

  # GCP message_retention_duration requires the "s" suffix (e.g. "604800s")
  retention_duration     = "${var.message_retention_duration}s"
  dlq_retention_duration = var.dlq.enabled ? "${var.dlq.dlq_retention_duration}s" : null

  topic_name = local.name_prefix
  dlq_name   = "${local.name_prefix}-dlq"
}

# ─── Main Topic ───────────────────────────────────────────────────────────────

resource "google_pubsub_topic" "main" {
  project = local.project_id
  name    = local.topic_name

  message_retention_duration = local.retention_duration

  # Message ordering is set at the publisher client level; the schema_settings
  # field is not required. Ordering is enforced per-publisher, not at topic level.
  # This label records the operator intent so Cloud Run and other publishers know
  # whether to enable ordering keys when publishing.
  labels = merge(var.md_metadata.default_tags, {
    message-ordering = var.message_ordering_enabled ? "enabled" : "disabled"
  })
}

# ─── Dead-Letter Queue Topic ──────────────────────────────────────────────────
# Only created when dlq.enabled == true. Pub/Sub requires the DLQ topic to exist
# before the subscription referencing it can be created by consumers.

resource "google_pubsub_topic" "dlq" {
  count = var.dlq.enabled ? 1 : 0

  project = local.project_id
  name    = local.dlq_name

  message_retention_duration = local.dlq_retention_duration

  labels = var.md_metadata.default_tags
}

# ─── Workload Publisher IAM ───────────────────────────────────────────────────
# Grant the landing zone's workload service account roles/pubsub.publisher on
# the main topic. This is the IAM role binding example pattern for this series:
#
#   member  = "serviceAccount:<workload_sa_email>"
#   role    = "roles/pubsub.publisher"
#   topic   = google_pubsub_topic.main.name
#
# Downstream bundles that need subscriber access should bind roles/pubsub.subscriber
# on this topic (or on their subscription) to the service account that reads messages.

resource "google_pubsub_topic_iam_member" "workload_publisher" {
  project = local.project_id
  topic   = google_pubsub_topic.main.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.landing_zone.workload_identity.service_account_email}"
}
