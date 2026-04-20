locals {
  project_id  = var.landing_zone.project_id
  name_prefix = var.md_metadata.name_prefix
  region      = var.landing_zone.network.region

  runtime_sa_email  = google_service_account.runtime.email
  runtime_sa_member = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_service_account" "runtime" {
  project      = local.project_id
  account_id   = substr(local.name_prefix, 0, 30)
  display_name = "Cloud Run Runtime — ${local.name_prefix}"
  description  = "Runtime identity for ${local.name_prefix}. Managed by Massdriver."
}

resource "google_cloud_run_v2_service" "main" {
  project  = local.project_id
  name     = local.name_prefix
  location = local.region

  ingress = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = local.runtime_sa_email

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  labels = var.md_metadata.default_tags
}
