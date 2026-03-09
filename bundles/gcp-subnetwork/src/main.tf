terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

provider "google" {
  project     = var.gcp_authentication.project_id
  region      = var.region
  credentials = jsonencode(var.gcp_authentication)
}

# Global VPC Network
resource "google_compute_network" "main" {
  name                    = var.md_metadata.name_prefix
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Regional Subnetwork
resource "google_compute_subnetwork" "main" {
  name          = "${var.md_metadata.name_prefix}-subnet"
  ip_cidr_range = var.cidr
  region        = var.region
  network       = google_compute_network.main.id

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private Services Access for Cloud SQL, etc.
resource "google_compute_global_address" "private_services" {
  name          = "${var.md_metadata.name_prefix}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = tonumber(split("/", var.private_services_cidr)[1])
  address       = split("/", var.private_services_cidr)[0]
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

# Cloud Router for NAT
resource "google_compute_router" "main" {
  name    = "${var.md_metadata.name_prefix}-router"
  region  = var.region
  network = google_compute_network.main.id
}

# Cloud NAT for egress
resource "google_compute_router_nat" "main" {
  name                               = "${var.md_metadata.name_prefix}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ALL"
  }
}

# VPC Access Connector for Cloud Run/Functions
resource "google_vpc_access_connector" "main" {
  name          = substr("${var.md_metadata.name_prefix}-vac", 0, 25)
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.8.0.0/28"
  min_instances = 2
  max_instances = 3
}

# Firewall rule to allow internal traffic
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.md_metadata.name_prefix}-allow-internal"
  network = google_compute_network.main.id

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

  source_ranges = [var.cidr, "10.8.0.0/28"]
  description   = "Allow all internal traffic within the VPC and from VPC Access Connector"
}
