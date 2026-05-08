# Storage bucket artifact — flat schema matching catalog-demo/gcp-storage-bucket.

resource "massdriver_artifact" "storage_bucket" {
  field = "storage_bucket"
  name  = "GCP Storage Bucket ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id       = local.project_id
    bucket_name      = google_storage_bucket.main.name
    bucket_url       = "gs://${google_storage_bucket.main.name}"
    bucket_self_link = google_storage_bucket.main.self_link
    location         = google_storage_bucket.main.location
    storage_class    = google_storage_bucket.main.storage_class
  })
}
