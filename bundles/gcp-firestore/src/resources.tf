resource "massdriver_resource" "database" {
  field = "database"
  name  = "Firestore ${google_firestore_database.main.name}"

  resource = jsonencode({
    id         = google_firestore_database.main.id
    name       = google_firestore_database.main.name
    project_id = var.gcp_service_account.project_id
    location   = google_firestore_database.main.location_id
    # Policy `id` is the GCP IAM role a consuming bundle binds to its own
    # service account, scoped to this database — e.g. a
    # google_project_iam_member resource in the consumer with
    # `role = <chosen policy id>` and `member = "serviceAccount:<consumer's
    # own service account>"`. Firestore IAM roles are project-scoped, not
    # per-database, so this only makes sense when a project has a single
    # Firestore database — the common case this bundle targets. Read picks
    # datastore.viewer, Read and Write picks datastore.user, Admin picks
    # datastore.owner.
    policies = [
      {
        id   = "roles/datastore.viewer"
        name = "Read"
      },
      {
        id   = "roles/datastore.user"
        name = "Read and Write"
      },
      {
        id   = "roles/datastore.owner"
        name = "Admin"
      }
    ]
  })
}
