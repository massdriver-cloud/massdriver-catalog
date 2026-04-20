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

  # Runtime SA is created by THIS bundle — not inherited from the landing zone.
  # The SA email and member string are sourced from the google_service_account resource below.
  # Use these locals anywhere an SA principal is needed (iam.tf, artifacts.tf).
  runtime_sa_email  = google_service_account.runtime.email
  runtime_sa_member = "serviceAccount:${google_service_account.runtime.email}"
}

# ─── Runtime Service Account ──────────────────────────────────────────────────
# Each Cloud Run service instance creates its own SA. This is the identity the
# service runs as and the principal that IAM bindings in iam.tf grant access to.
#
# account_id is derived from name_prefix and capped at 30 chars (GCP limit is 30).
# The SA is created in the landing zone's project — the project that owns the
# Cloud Run service and the upstream data resources.
#
# IMPORTANT: This SA is destroyed and recreated if the name_prefix changes (e.g.,
# if the package is renamed). That is a destructive operation — downstream IAM
# bindings referencing the old email are invalidated. Plan SA naming carefully
# before first deploy; treat it as immutable after that.

resource "google_service_account" "runtime" {
  project      = local.project_id
  account_id   = substr(local.name_prefix, 0, 30)
  display_name = "Cloud Run Runtime — ${local.name_prefix}"
  description  = "Runtime identity for Cloud Run service ${local.name_prefix}. Managed by Massdriver."
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
    # Run every revision as this bundle's own runtime service account (created above).
    # iam.tf grants this SA the minimum required roles on any connected upstream artifact.
    service_account = local.runtime_sa_email

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
