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

  # Resolve which destination connection is wired. Exactly one must be non-null.
  # The precondition on google_logging_project_sink.main enforces this at plan time.
  has_bigquery = var.bigquery_dataset != null
  has_gcs      = var.storage_bucket != null

  destination = local.has_bigquery ? (
    "bigquery.googleapis.com/projects/${var.bigquery_dataset.project_id}/datasets/${var.bigquery_dataset.dataset_id}"
    ) : local.has_gcs ? (
    "storage.googleapis.com/${var.storage_bucket.bucket_name}"
  ) : ""

  destination_type = local.has_bigquery ? "bigquery" : "gcs"
}

# ─── Cloud Logging Project Sink ───────────────────────────────────────────────

resource "google_logging_project_sink" "main" {
  project     = local.project_id
  name        = local.name_prefix
  destination = local.destination
  filter      = var.filter != "" ? var.filter : null

  # unique_writer_identity = true ensures the sink gets its own Google-managed SA
  # rather than sharing the project-level logging SA. Required when granting the
  # sink's writer access on a specific dataset or bucket (otherwise IAM bindings
  # would affect ALL sinks in the project). This is non-negotiable.
  unique_writer_identity = true

  dynamic "bigquery_options" {
    for_each = local.has_bigquery ? [1] : []
    content {
      use_partitioned_tables = var.use_partitioned_tables
    }
  }

  dynamic "exclusions" {
    for_each = var.exclusions
    content {
      name        = exclusions.value.name
      filter      = exclusions.value.filter
      description = try(exclusions.value.description, null)
      disabled    = try(exclusions.value.disabled, false)
    }
  }

  lifecycle {
    precondition {
      condition     = (var.bigquery_dataset != null) != (var.storage_bucket != null)
      error_message = "Connect either a BigQuery dataset or a Storage bucket as the sink destination, not both and not neither."
    }
  }
}

# ─── Sink Writer IAM Binding ──────────────────────────────────────────────────
# Grant the Google-managed sink writer SA the minimum role on the destination.
# writer_identity is not known until the sink is created — Terraform handles the
# dependency automatically via the reference below.

resource "google_bigquery_dataset_iam_member" "sink_writer" {
  count = local.has_bigquery ? 1 : 0

  project    = var.bigquery_dataset.project_id
  dataset_id = var.bigquery_dataset.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.main.writer_identity
}

resource "google_storage_bucket_iam_member" "sink_writer" {
  count = local.has_gcs ? 1 : 0

  bucket = var.storage_bucket.bucket_name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.main.writer_identity
}
