# BigQuery table artifact — matches catalog-demo/gcp-bigquery-table schema.

resource "massdriver_artifact" "bigquery_table" {
  field = "bigquery_table"
  name  = "GCP BigQuery Table ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id      = local.project_id
    dataset_id      = local.dataset_id
    table_id        = google_bigquery_table.main.table_id
    table_full_name = "${local.project_id}.${local.dataset_id}.${google_bigquery_table.main.table_id}"
  })
}
