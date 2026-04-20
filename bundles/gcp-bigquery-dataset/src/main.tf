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

  # Convert days → milliseconds for the BigQuery API. BigQuery requires ms.
  # 0 or null input means "no expiration" → pass null to terraform resource.
  default_table_expiration_ms = (
    var.default_table_expiration_days != null && var.default_table_expiration_days > 0
    ? var.default_table_expiration_days * 24 * 60 * 60 * 1000
    : null
  )
}

# ─── BigQuery Dataset ──────────────────────────────────────────────────────────

resource "google_bigquery_dataset" "main" {
  project    = local.project_id
  dataset_id = var.dataset_id
  location   = var.location

  friendly_name = var.friendly_name != null ? var.friendly_name : null
  description   = var.description != null ? var.description : null

  # ── Default table expiration ─────────────────────────────────────────────────
  # Only applies to NEW tables created after this setting is applied. Existing
  # tables in the dataset are NOT retroactively expired. Set to null for no
  # automatic expiration (recommended for production).
  default_table_expiration_ms = local.default_table_expiration_ms

  # ── Delete protection ────────────────────────────────────────────────────────
  # When true, Terraform will refuse to destroy this dataset until the flag is
  # first set to false and re-applied (a two-step destroy). Prevents accidental
  # data loss. Default is false so non-prod environments can be torn down freely.
  delete_contents_on_destroy = !var.delete_protection

  # Google-managed encryption is used for all datasets provisioned by this bundle.
  # CMEK is intentionally out of scope — see src/.checkov.yml for CKV_GCP_81 skip rationale.

  labels = var.md_metadata.default_tags
}

# ─── Workload IAM Binding ──────────────────────────────────────────────────────
# Grant the landing zone's workload service account roles/bigquery.dataEditor on
# this dataset. dataEditor allows reading, writing, and deleting table data, as
# well as creating and deleting tables within the dataset — without granting
# dataset-level admin (which would allow dropping the dataset itself).
#
# IAM role binding pattern for this series:
#   member = "serviceAccount:<workload_sa_email>"
#   role   = "roles/bigquery.dataEditor"
#   resource = google_bigquery_dataset.main.dataset_id (dataset-level binding)
#
# Note: This is a DATASET-level binding — it propagates to all current and future
# tables in the dataset. For table-level isolation, use google_bigquery_table_iam_member
# instead. For read-only access, bind roles/bigquery.dataViewer.
#
# Downstream bundles that need read-only access should bind roles/bigquery.dataViewer
# on this dataset using the bigquery_dataset artifact's dataset_id and project_id.

resource "google_bigquery_dataset_iam_member" "workload_data_editor" {
  project    = local.project_id
  dataset_id = google_bigquery_dataset.main.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${var.landing_zone.workload_identity.service_account_email}"
}
