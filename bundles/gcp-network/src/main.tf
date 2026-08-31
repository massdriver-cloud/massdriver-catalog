locals {
  # md_metadata.name_prefix is unique per instance per environment, so two
  # environments of this project can each hold a network without name clashes.
  network_name = "net-${var.md_metadata.name_prefix}"

  subnets_by_name = { for s in var.subnets : s.name => s }

  # google_vpc_access_connector is the one resource in this bundle with a
  # short name limit: 25 characters total, lowercase letters/digits/hyphens,
  # must start with a letter and end with a letter or digit. name_prefix alone
  # can exceed that once project/environment/component names are long, so
  # truncate defensively and drop a trailing hyphen if the cut lands on one.
  connector_name = trimsuffix(substr("c-${var.md_metadata.name_prefix}", 0, 25), "-")
}

# Note: google_compute_network, google_compute_subnetwork, and
# google_vpc_access_connector do not support GCP resource labels — unlike most
# other resources in this catalog, there is nothing to normalize md_metadata's
# default_tags onto here.

# Required APIs. disable_on_destroy is false so tearing down this bundle never
# disables services other components in the project may also depend on.
resource "google_project_service" "compute" {
  project            = var.gcp_service_account.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking" {
  project            = var.gcp_service_account.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "vpcaccess" {
  project            = var.gcp_service_account.project_id
  service            = "vpcaccess.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "main" {
  name                    = local.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  depends_on              = [google_project_service.compute]
}

resource "google_compute_subnetwork" "main" {
  for_each      = local.subnets_by_name
  name          = "${each.value.name}-${var.md_metadata.name_prefix}"
  network       = google_compute_network.main.id
  region        = each.value.region
  ip_cidr_range = each.value.cidr

  # Required for Cloud Run/GKE to reach the internet via Cloud NAT, and for
  # Google APIs to be reachable without public IPs on private workloads.
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.value.name
      ip_cidr_range = secondary_ip_range.value.cidr
    }
  }

  # Traffic metadata for security review and incident response. Configurable
  # rather than hardcoded because logging volume (and cost) scales with
  # traffic — some environments genuinely don't want to pay for it.
  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# Custom-mode VPCs start with zero firewall rules — nothing like the "default"
# network's implicit allow-internal rule exists here. Without this, the
# Serverless VPC connector cannot reach a private-IP Cloud SQL instance (or
# anything else) on this network: all ingress is denied until something
# explicitly allows it. Scoped to traffic sourced from this network's own
# CIDR only, not 0.0.0.0/0.
resource "google_compute_firewall" "allow_internal" {
  name      = "allow-internal-${var.md_metadata.name_prefix}"
  network   = google_compute_network.main.id
  direction = "INGRESS"

  source_ranges = [var.cidr]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
}

# Private Service Access: a reserved peering range plus the peering connection
# itself. Cloud SQL (and Memorystore) attach to this network over the peering
# to hand out a private IP, instead of requiring a public IP with authorized
# networks.
resource "google_compute_global_address" "psa_range" {
  count         = var.private_service_access_enabled ? 1 : 0
  name          = "psa-${var.md_metadata.name_prefix}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_service_access_prefix_length
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "psa" {
  count                   = var.private_service_access_enabled ? 1 : 0
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa_range[0].name]
  depends_on              = [google_project_service.servicenetworking]
}

# Serverless VPC Access connector: gives Cloud Run (and Cloud Functions) a path
# onto this network's private IP space. Without this, a Cloud Run service can
# only reach the public internet, never a private Cloud SQL IP or an internal
# load balancer.
resource "google_vpc_access_connector" "serverless" {
  name          = local.connector_name
  region        = var.connector_region
  network       = google_compute_network.main.name
  ip_cidr_range = var.connector_cidr
  min_instances = var.connector_min_instances
  max_instances = var.connector_max_instances
  machine_type  = var.connector_machine_type
  depends_on    = [google_project_service.vpcaccess, google_compute_subnetwork.main]
}
