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

# Enable Cloud Run API
resource "google_project_service" "run_api" {
  project            = var.gcp_authentication.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

locals {
  # Build environment variables from params and optional database connection
  base_env = var.container.env != null ? var.container.env : []

  db_env = var.database != null ? [
    {
      name  = "DATABASE_HOST"
      value = var.database.auth.hostname
    },
    {
      name  = "DATABASE_PORT"
      value = tostring(var.database.auth.port)
    },
    {
      name  = "DATABASE_NAME"
      value = var.database.auth.database
    },
    {
      name  = "DATABASE_USER"
      value = var.database.auth.username
    },
    {
      name  = "DATABASE_PASSWORD"
      value = var.database.auth.password
    },
    {
      name  = "DATABASE_URL"
      value = "postgresql://${var.database.auth.username}:${var.database.auth.password}@${var.database.auth.hostname}:${var.database.auth.port}/${var.database.auth.database}"
    }
  ] : []

  all_env = concat(local.base_env, local.db_env)

  min_instances = try(var.scaling.min_instances, 0)
  max_instances = try(var.scaling.max_instances, 10)
}

resource "google_cloud_run_v2_service" "main" {
  name     = var.md_metadata.name_prefix
  location = var.region
  ingress  = "INGRESS_TRAFFIC_${upper(replace(var.ingress, "-", "_"))}"

  depends_on = [google_project_service.run_api]

  template {
    scaling {
      min_instance_count = local.min_instances
      max_instance_count = local.max_instances
    }

    containers {
      image = var.container.image

      ports {
        container_port = var.container.port
      }

      resources {
        limits = {
          cpu    = var.container.cpu
          memory = var.container.memory
        }
      }

      dynamic "env" {
        for_each = local.all_env
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
    }

    # VPC connector for private network access (if subnetwork provided)
    dynamic "vpc_access" {
      for_each = var.subnetwork != null ? [1] : []
      content {
        connector = var.subnetwork.vpc_access_connector
        egress    = "ALL_TRAFFIC"
      }
    }
  }

  labels = var.md_metadata.default_tags
}

# Allow unauthenticated access (public service)
resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.ingress == "all" ? 1 : 0
  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
