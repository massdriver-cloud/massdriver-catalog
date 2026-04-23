resource "massdriver_artifact" "network" {
  field = "network"
  name  = "GCP Network ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id        = var.gcp_authentication.project_id
    network_name      = google_compute_network.vpc.name
    network_self_link = google_compute_network.vpc.self_link
    region            = var.region
    primary_subnet = {
      name      = google_compute_subnetwork.primary.name
      cidr      = google_compute_subnetwork.primary.ip_cidr_range
      self_link = google_compute_subnetwork.primary.self_link
    }
  })
}
