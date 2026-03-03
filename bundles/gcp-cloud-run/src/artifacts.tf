resource "massdriver_artifact" "service" {
  field = "service"
  name  = "Cloud Run ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    name          = google_cloud_run_v2_service.main.name
    deployment_id = google_cloud_run_v2_service.main.uid
    service_url   = google_cloud_run_v2_service.main.uri
    tags          = var.md_metadata.default_tags
  })
}
