locals {
  # Firestore database IDs must be 4-63 characters: lowercase letters,
  # digits, and hyphens; start with a letter; end with a letter or digit; no
  # consecutive hyphens. name_prefix is already lowercase alphanumerics and
  # hyphens, so this just adds a stable, descriptive prefix and defensively
  # truncates to the length limit.
  #
  # Firestore database IDs are only unique within a single GCP project (not
  # globally, unlike GCS bucket names), so name_prefix alone — already unique
  # per instance per environment — is enough; no user-supplied name needed.
  database_id = trimsuffix(substr("db-${var.md_metadata.name_prefix}", 0, 63), "-")
}

# Note: unlike most resources in this catalog, google_firestore_database does
# not support GCP resource labels — there is nothing to normalize
# md_metadata's default_tags onto here.

# Required API. disable_on_destroy is false so tearing down this bundle never
# disables Firestore for other components in the project that also depend on
# it.
resource "google_project_service" "firestore" {
  project            = var.gcp_service_account.project_id
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_firestore_database" "main" {
  project     = var.gcp_service_account.project_id
  name        = local.database_id
  location_id = var.location

  # This bundle only ever creates a standalone, native-mode Firestore
  # database — not the older Datastore mode, and not layered on an App
  # Engine app. Neither is exposed as a param: Datastore mode is a different
  # product with a different client API, and app_engine_integration_mode
  # only matters if this project already has an App Engine app this bundle
  # has no business knowing about.
  type                        = "FIRESTORE_NATIVE"
  app_engine_integration_mode = "DISABLED"

  delete_protection_state = var.enable_delete_protection ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"

  point_in_time_recovery_enablement = (
    var.enable_point_in_time_recovery
    ? "POINT_IN_TIME_RECOVERY_ENABLED"
    : "POINT_IN_TIME_RECOVERY_DISABLED"
  )

  depends_on = [google_project_service.firestore]
}
