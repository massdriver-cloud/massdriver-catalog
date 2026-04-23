# Workbench instance artifact — matches catalog-demo/gcp-vertex-workbench schema.
# Emitted after the instance is provisioned and the proxy_uri is known.
# The proxy_url may be empty on first deploy if the instance is still starting.
# Downstream connections can use instance_service_account_member to grant the
# Workbench additional IAM roles on resources outside this bundle.

resource "massdriver_artifact" "vertex_workbench" {
  field = "vertex_workbench"
  name  = "GCP Vertex Workbench ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id                      = local.project_id
    instance_name                   = google_workbench_instance.main.name
    location                        = google_workbench_instance.main.location
    proxy_url                       = google_workbench_instance.main.proxy_uri
    instance_service_account_email  = local.instance_sa_email
    instance_service_account_member = local.instance_sa_member
  })
}
