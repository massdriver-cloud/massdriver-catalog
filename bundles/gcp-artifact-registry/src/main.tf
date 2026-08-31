locals {
  # md_metadata.name_prefix is unique per instance per environment, so two
  # environments of the same project can hold a repository of the same name.
  repository_id = "${var.repository_name}-${var.md_metadata.name_prefix}"

  registry_url = "${var.location}-docker.pkg.dev/${var.gcp_service_account.project_id}/${google_artifact_registry_repository.main.repository_id}"

  # GCP only accepts lowercase letters, digits, `-` and `_` in label keys and
  # values, capped at 63 characters. Massdriver's default tags are not written
  # to that spec, and an out-of-spec label fails the whole apply — so normalize
  # rather than passing them through untouched.
  gcp_labels = {
    for key, value in var.md_metadata.default_tags :
    substr(lower(replace(key, "/[^a-zA-Z0-9_-]/", "_")), 0, 63) => substr(lower(replace(value, "/[^a-zA-Z0-9_-]/", "_")), 0, 63)
  }
}

resource "google_artifact_registry_repository" "main" {
  location      = var.location
  repository_id = local.repository_id
  format        = "DOCKER"
  description   = "Managed by Massdriver — ${var.md_metadata.name_prefix}"

  labels = local.gcp_labels

  docker_config {
    immutable_tags = var.immutable_tags
  }

  # Untagged images accumulate every time a tag is moved to a new build. Left
  # alone they are billed as storage forever.
  dynamic "cleanup_policies" {
    for_each = var.cleanup_untagged_after_days > 0 ? [1] : []
    content {
      id     = "delete-untagged"
      action = "DELETE"
      condition {
        tag_state  = "UNTAGGED"
        older_than = "${var.cleanup_untagged_after_days * 24}h"
      }
    }
  }
}
