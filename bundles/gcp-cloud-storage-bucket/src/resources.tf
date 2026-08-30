resource "massdriver_resource" "bucket" {
  field = "bucket"
  name  = "Storage Bucket ${google_storage_bucket.main.name}"

  resource = jsonencode({
    id     = google_storage_bucket.main.id
    name   = google_storage_bucket.main.name
    url    = "gs://${google_storage_bucket.main.name}"
    region = google_storage_bucket.main.location
    # Policy `id` is the GCP IAM role a consuming bundle binds to its own
    # service account, scoped to this bucket — e.g. a
    # google_storage_bucket_iam_member resource in the consumer with
    # `bucket = <this bucket's name>`, `role = <chosen policy id>`, and
    # `member = "serviceAccount:<consumer's own service account>"`. Read
    # picks objectViewer, Read and Write picks objectAdmin (full control of
    # objects, no bucket-level settings), Admin also allows managing the
    # bucket itself (versioning, lifecycle rules, IAM).
    policies = [
      {
        id   = "roles/storage.objectViewer"
        name = "Read"
      },
      {
        id   = "roles/storage.objectAdmin"
        name = "Read and Write"
      },
      {
        id   = "roles/storage.admin"
        name = "Admin (manage bucket settings)"
      }
    ]
  })
}
