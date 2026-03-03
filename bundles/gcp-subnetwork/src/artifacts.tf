resource "massdriver_artifact" "subnetwork" {
  field = "subnetwork"
  name  = "GCP Subnetwork ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    network_id                  = google_compute_network.main.id
    subnet_id                   = google_compute_subnetwork.main.id
    project_id                  = var.gcp_authentication.project_id
    region                      = var.region
    cidr                        = var.cidr
    vpc_access_connector        = google_vpc_access_connector.main.id
    private_services_connection = google_service_networking_connection.private_services.id
  })
}
