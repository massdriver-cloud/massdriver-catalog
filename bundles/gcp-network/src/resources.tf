resource "massdriver_resource" "network" {
  field = "network"
  name  = "Network ${google_compute_network.main.name}"

  resource = jsonencode({
    id                     = google_compute_network.main.id
    self_link              = google_compute_network.main.self_link
    name                   = google_compute_network.main.name
    project_id             = var.gcp_service_account.project_id
    cidr                   = var.cidr
    private_service_access = var.private_service_access_enabled
    subnets = [
      for name, subnet in local.subnets_by_name : {
        id               = google_compute_subnetwork.main[name].id
        self_link        = google_compute_subnetwork.main[name].self_link
        name             = google_compute_subnetwork.main[name].name
        region           = subnet.region
        cidr             = subnet.cidr
        secondary_ranges = subnet.secondary_ranges
      }
    ]
  })
}

resource "massdriver_resource" "serverless_connector" {
  field = "serverless_connector"
  name  = "Serverless Connector ${google_vpc_access_connector.serverless.name}"

  resource = jsonencode({
    id      = google_vpc_access_connector.serverless.id
    name    = google_vpc_access_connector.serverless.name
    region  = var.connector_region
    network = google_compute_network.main.name
  })
}
