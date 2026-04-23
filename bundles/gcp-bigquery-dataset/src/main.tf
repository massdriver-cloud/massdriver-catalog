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
  dataset_id  = var.dataset_id

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

# ─── No workload IAM binding here ────────────────────────────────────────────
# BigQuery datasets do not own a runtime identity. The landing zone no longer
# provides a shared workload SA. Consumer bundles (e.g. gcp-cloud-run-service)
# create their OWN service account and the Cloud Run bundle grants dataEditor
# access on this dataset when connected on the canvas.
#
# Artifact policy pattern — grant a consumer's SA data editor access:
#   resource "google_bigquery_dataset_iam_member" "runtime_editor" {
#     project    = var.bigquery_dataset.project_id
#     dataset_id = var.bigquery_dataset.dataset_id
#     role       = "roles/bigquery.dataEditor"
#     member     = "serviceAccount:<consumer-sa-email>"
#   }
