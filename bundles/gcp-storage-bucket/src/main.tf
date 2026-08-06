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

  # GCS bucket names must be globally unique. The name_prefix already incorporates
  # the Massdriver environment slug, so we use it directly as the bucket name.
  bucket_name = local.name_prefix
}

# ─── GCS Bucket ───────────────────────────────────────────────────────────────

resource "google_storage_bucket" "main" {
  project  = local.project_id
  name     = local.bucket_name
  location = var.location

  storage_class = var.storage_class

  # ── Security baselines — NOT configurable ────────────────────────────────────
  # uniform_bucket_level_access: Disables legacy object-level ACLs and enforces
  # IAM-only access control. This is a GCP best practice and a Checkov requirement
  # (CKV_GCP_29). Allowing ACLs alongside IAM creates split access control models
  # that are difficult to audit and easy to misconfigure.
  uniform_bucket_level_access = true

  # public_access_prevention: Set to "enforced" to block all public object access
  # regardless of IAM policies or ACLs. This prevents accidental data exposure via
  # allUsers/allAuthenticatedUsers grants (CKV_GCP_114). This is a non-negotiable
  # baseline for all environments in this data platform series.
  public_access_prevention = "enforced"
  # ─────────────────────────────────────────────────────────────────────────────

  versioning {
    enabled = var.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = try(lifecycle_rule.value.action.storage_class, null)
      }
      condition {
        age        = lifecycle_rule.value.condition.age_days
        with_state = try(lifecycle_rule.value.condition.with_state, null)
      }
    }
  }

  labels = var.md_metadata.default_tags
}

# ─── No workload IAM binding here ────────────────────────────────────────────
# GCS buckets do not own a runtime identity. The landing zone no longer provides
# a shared workload SA. Consumer bundles (e.g. gcp-cloud-run-service) create their
# OWN service account and the Cloud Run bundle grants objectUser access on this
# bucket when connected on the canvas.
#
# Artifact policy pattern — grant a consumer's SA object access:
#   resource "google_storage_bucket_iam_member" "runtime_object_user" {
#     bucket = var.storage_bucket.bucket_name
#     role   = "roles/storage.objectUser"
#     member = "serviceAccount:<consumer-sa-email>"
#   }
