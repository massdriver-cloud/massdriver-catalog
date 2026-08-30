locals {
  # md_metadata.name_prefix is unique per instance per environment. Bucket
  # names are globally unique across ALL of GCP though, not just this
  # project, so the user's bucket_name alone is not enough — combine it with
  # name_prefix and defensively truncate to GCS's 63-character limit.
  bucket_name = trimsuffix(substr("${var.bucket_name}-${var.md_metadata.name_prefix}", 0, 63), "-")

  # GCP only accepts lowercase letters, digits, `-` and `_` in label keys and
  # values, capped at 63 characters. Massdriver's default tags are not written
  # to that spec, and an out-of-spec label fails the whole apply — so normalize
  # rather than passing them through untouched.
  gcp_labels = {
    for key, value in var.md_metadata.default_tags :
    substr(lower(replace(key, "/[^a-zA-Z0-9_-]/", "_")), 0, 63) => substr(lower(replace(value, "/[^a-zA-Z0-9_-]/", "_")), 0, 63)
  }
}

# Required APIs. disable_on_destroy is false so tearing down this bundle
# never disables these for other components in the project that also depend
# on them.
resource "google_project_service" "storage" {
  project            = var.gcp_service_account.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Only needed when enable_cmek is on, but kept unconditional (like the
# storage API above) rather than toggled by count — a project either uses
# Cloud KMS or doesn't, and enabling the API has no cost or side effect on
# its own.
resource "google_project_service" "kms" {
  project            = var.gcp_service_account.project_id
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = false
}

# The Cloud Storage service agent for this project — Google creates it
# automatically the first time the Storage API is used. Only looked up (not
# created) so it can be granted permission to use the customer-managed
# encryption key below.
data "google_storage_project_service_account" "gcs" {
  project    = var.gcp_service_account.project_id
  depends_on = [google_project_service.storage]
}

# Customer-managed encryption key (CMEK). GCP already encrypts every object
# in this bucket at rest by default with a Google-owned key, whether or not
# this is enabled. Turning it on swaps in a key this project owns instead, so
# access to the data can be cut off independently by disabling the key — a
# capability a Google-owned key does not offer.
#
# Key rings and crypto keys cannot ever be deleted in GCP (only individual
# key versions can be scheduled for destruction) — "destroying" one in
# Terraform only removes it from state, it never calls a delete API, and the
# name stays reserved in the project/location forever. A name built only from
# name_prefix would collide with that orphaned-but-still-existing key ring on
# the next create after any full teardown-and-recreate of this instance, so a
# random suffix is mixed in. It's stable across ordinary redeploys (state
# persists), and only changes if the instance's state is wiped by a full
# destroy, which is exactly when a fresh name is needed.
resource "random_id" "kms_suffix" {
  count       = var.enable_cmek ? 1 : 0
  byte_length = 4
}

resource "google_kms_key_ring" "main" {
  count      = var.enable_cmek ? 1 : 0
  name       = "kr-${var.md_metadata.name_prefix}-${random_id.kms_suffix[0].hex}"
  location   = var.location
  project    = var.gcp_service_account.project_id
  depends_on = [google_project_service.kms]
}

resource "google_kms_crypto_key" "main" {
  count           = var.enable_cmek ? 1 : 0
  name            = "key-${var.md_metadata.name_prefix}-${random_id.kms_suffix[0].hex}"
  key_ring        = google_kms_key_ring.main[0].id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key_iam_member" "gcs" {
  count         = var.enable_cmek ? 1 : 0
  crypto_key_id = google_kms_crypto_key.main[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

# Dedicated bucket to receive access logs for the primary bucket below. Kept
# separate because a bucket logging to itself would just duplicate every log
# entry into the thing generating it, and access logs routinely need to
# outlive the objects that generated them.
#
# This bucket is deliberately not itself configured with a `logging` block —
# Google's own guidance for GCS access logs is that the destination bucket
# should not have logging enabled, to avoid an unbounded chain of buckets
# each logging the last. That's true in every environment, including
# production, so a Checkov finding on this specific resource for "should log
# access" / "should not log to itself" is an expected, structural false
# positive rather than a real gap — see operator.md.
resource "google_storage_bucket" "logs" {
  count                       = var.enable_access_logging ? 1 : 0
  name                        = "${local.bucket_name}-logs"
  location                    = var.location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  # Log data has no independent value to protect against accidental deletion
  # of this instance the way user data does.
  force_destroy = true
  labels        = local.gcp_labels

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.storage]
}

resource "google_storage_bucket" "main" {
  name          = local.bucket_name
  location      = var.location
  storage_class = var.storage_class
  labels        = local.gcp_labels

  # Non-negotiable, not exposed as a param: every object is governed by IAM,
  # never per-object ACLs, and the bucket can never be made public. There is
  # no legitimate case for this bundle to offer a public bucket — anything
  # that genuinely needs public objects (e.g. static website hosting) is a
  # different bundle with a different threat model.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Data safety over convenience: if the bucket still holds objects,
  # destroying this instance should fail loudly rather than silently delete
  # everything in it. Empty the bucket by hand first — see operator.md.
  force_destroy = false

  versioning {
    enabled = var.enable_versioning
  }

  dynamic "logging" {
    for_each = var.enable_access_logging ? [1] : []
    content {
      log_bucket = google_storage_bucket.logs[0].name
    }
  }

  dynamic "encryption" {
    for_each = var.enable_cmek ? [1] : []
    content {
      default_kms_key_name = google_kms_crypto_key.main[0].id
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.delete_objects_after_days > 0 ? [1] : []
    content {
      action {
        type = "Delete"
      }
      condition {
        age = var.delete_objects_after_days
      }
    }
  }

  depends_on = [
    google_project_service.storage,
    google_kms_crypto_key_iam_member.gcs,
  ]
}
