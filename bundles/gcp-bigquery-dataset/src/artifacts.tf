# BigQuery dataset artifact — matches catalog-demo/gcp-bigquery-dataset schema.

resource "massdriver_artifact" "bigquery_dataset" {
  field = "bigquery_dataset"
  name  = "GCP BigQuery Dataset ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id        = local.project_id
    dataset_id        = google_bigquery_dataset.main.dataset_id
    dataset_full_name = "${local.project_id}.${google_bigquery_dataset.main.dataset_id}"
    location          = google_bigquery_dataset.main.location
    friendly_name     = google_bigquery_dataset.main.friendly_name != "" ? google_bigquery_dataset.main.friendly_name : null
  })
}
