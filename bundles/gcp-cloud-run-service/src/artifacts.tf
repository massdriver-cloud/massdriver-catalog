# Cloud Run service artifact — matches catalog-demo/gcp-cloud-run-service schema.
# Emits after the service is fully deployed and the first revision is ready.
# Downstream bundles (Scheduler, Pub/Sub push subscriptions) consume service_url
# and runtime_service_account_member to configure invocation and IAM.
#
# runtime_service_account_email / runtime_service_account_member now reference
# THIS bundle's own runtime SA (created in main.tf), NOT the landing zone SA.

resource "massdriver_artifact" "cloud_run_service" {
  field = "cloud_run_service"
  name  = "GCP Cloud Run Service ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id                     = local.project_id
    service_name                   = google_cloud_run_v2_service.main.name
    service_url                    = google_cloud_run_v2_service.main.uri
    location                       = google_cloud_run_v2_service.main.location
    latest_ready_revision          = google_cloud_run_v2_service.main.latest_ready_revision
    runtime_service_account_email  = local.runtime_sa_email
    runtime_service_account_member = local.runtime_sa_member
  })
}
