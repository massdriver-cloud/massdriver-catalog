terraform {
  required_version = ">= 1.0"
  required_providers {
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# See ../build/providers.tf for why nulls are dropped before re-encoding.
locals {
  gcp_credentials = jsonencode({
    for key, value in var.gcp_service_account : key => value if value != null
  })
}

provider "google" {
  project     = var.gcp_service_account.project_id
  credentials = local.gcp_credentials
  region      = var.region
}
