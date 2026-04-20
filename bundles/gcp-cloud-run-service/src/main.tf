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
}

locals {
  project_id  = var.landing_zone.project_id
  name_prefix = var.md_metadata.name_prefix
  region      = var.landing_zone.network.region

  # The workload SA is defined once in the landing zone; all upstream IAM
  # bindings in iam.tf reference this local so the principal is never duplicated.
  workload_sa_email  = var.landing_zone.workload_identity.service_account_email
  workload_sa_member = "serviceAccount:${local.workload_sa_email}"
}

# ─── Cloud Run v2 Service ──────────────────────────────────────────────────────
# Uses the v2 API (google_cloud_run_v2_service), which is the current GA surface.
# The v1 resource (google_cloud_run_service) is deprecated and lacks v2-only
# features such as direct VPC egress and improved traffic management.

resource "google_cloud_run_v2_service" "main" {
  project  = local.project_id
  name     = local.name_prefix
  location = local.region

  # ── Ingress ─────────────────────────────────────────────────────────────────
  # Controls which traffic sources can reach this service.
  # Changing ingress triggers a full revision replacement (cold start expected).
  ingress = upper(var.ingress) == "INTERNAL-AND-CLOUD-LOAD-BALANCING" ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : (
    upper(var.ingress) == "INTERNAL" ? "INGRESS_TRAFFIC_INTERNAL_ONLY" : "INGRESS_TRAFFIC_ALL"
  )

  template {
    # ── Runtime identity ──────────────────────────────────────────────────────
    # Run every revision as the landing zone's shared workload service account.
    # This is the identity that upstream IAM bindings (iam.tf) grant access to.
    # Per-service SAs are out of scope; use a separate landing-zone-style bundle
    # if your workload requires a dedicated SA with narrower permissions.
    service_account = local.workload_sa_email

    # ── Scaling ───────────────────────────────────────────────────────────────
    # min_instance_count > 0 disables scale-to-zero. You pay for idle capacity.
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      ports {
        container_port = var.port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }
    }
  }

  labels = var.md_metadata.default_tags

  lifecycle {
    ignore_changes = [
      # Allow external traffic management tools (e.g., gcloud beta run services
      # update-traffic) to adjust revision splits without Terraform reverting them.
      template[0].labels,
    ]
  }
}

# ─── Public Invoker IAM ────────────────────────────────────────────────────────
# Only created when allow_unauthenticated = true. Grants roles/run.invoker to
# allUsers, making the .run.app URL publicly accessible without a Bearer token.
# When false, callers must present a valid GCP identity token.
#
# Note: This IAM binding is independent of ingress. You can have:
#   ingress=all + allow_unauthenticated=false → public network, authenticated
#   ingress=all + allow_unauthenticated=true  → fully public (anonymous access)
#   ingress=internal + allow_unauthenticated=false → VPC-only, authenticated

resource "google_cloud_run_v2_service_iam_member" "all_users_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = local.project_id
  location = local.region
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
