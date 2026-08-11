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

# The GCP service account connection is the credential imported into Massdriver.
# In v2 the connection payload is flat — the fields sit at the top level and map
# one-to-one onto the JSON key file Google issues, so it can be re-encoded and
# handed to the provider.
#
# `universe_domain` is optional, because keys issued before Google added the
# field do not carry it. Absent fields come through as null, and a null in the
# credentials JSON is not the same as an omitted one — the provider rejects it.
# Drop nulls rather than passing them through.
locals {
  gcp_credentials = jsonencode({
    for key, value in var.gcp_service_account : key => value if value != null
  })
}

provider "google" {
  project     = var.gcp_service_account.project_id
  credentials = local.gcp_credentials
  region      = var.location
}
