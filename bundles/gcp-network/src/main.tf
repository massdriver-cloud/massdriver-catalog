terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

provider "google" {
  project     = var.gcp_authentication.project_id
  credentials = jsonencode(var.gcp_authentication)
  region      = var.region
}

locals {
  subnet_name = "${var.network_name}-${var.region}"
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  description             = "Data platform VPC managed by Massdriver — ${var.md_metadata.name_prefix}"
}

resource "google_compute_subnetwork" "primary" {
  name                     = local.subnet_name
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Baseline deny-all ingress firewall. Workload bundles add targeted allow rules
# (e.g. allow 443 from load balancer IP ranges). This satisfies CKV2_GCP_18 and
# enforces explicit allowlisting instead of relying on GCP's permissive defaults.
resource "google_compute_firewall" "deny_all_ingress" {
  name        = "${var.network_name}-deny-all-ingress"
  network     = google_compute_network.vpc.id
  description = "Baseline deny-all ingress. Workload bundles add targeted allow rules."
  direction   = "INGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}
