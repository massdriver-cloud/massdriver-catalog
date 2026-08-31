resource "massdriver_resource" "service" {
  field = "service"
  name  = "Cloud Run ${google_cloud_run_v2_service.app.name}"

  resource = jsonencode({
    id     = google_cloud_run_v2_service.app.id
    name   = google_cloud_run_v2_service.app.name
    url    = google_cloud_run_v2_service.app.uri
    region = var.region
  })
}
