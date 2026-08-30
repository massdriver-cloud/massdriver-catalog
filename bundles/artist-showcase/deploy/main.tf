# Independently re-derives the image tag the build step produced (see the
# comment at the top of ../build/main.tf) and deploys it to Cloud Run. This
# step never reads Terraform state or outputs from the build step — both
# steps compute the same tag from the same md_metadata field, which is
# identical across every step of one deployment.
locals {
  image_tag = lower(replace(var.md_metadata.package.deployment_enqueued_at, ":", "-"))
  image_uri = "${var.container_registry.registry_url}/${var.service_name}:${local.image_tag}"

  service_id = trimsuffix(substr("${var.service_name}-${var.md_metadata.name_prefix}", 0, 63), "-")

  # google_service_account.account_id is capped at 30 characters.
  runtime_sa_id = trimsuffix(substr("run-${var.md_metadata.name_prefix}", 0, 30), "-")

  size_specs = {
    small  = { cpu = "1", memory = "512Mi" }
    medium = { cpu = "2", memory = "1Gi" }
    large  = { cpu = "4", memory = "2Gi" }
  }
  size = local.size_specs[var.size]

  # Optional connections auto-wire as environment variables so the app never
  # needs its own config UI for where its database lives. Secrets
  # (the database password) ride the same path other bundles in this catalog
  # already use for sensitive values passed through Terraform.
  # One read-only login, granted a single table. There is no second connection and
  # no schema of its own: this site can serve the roster and do nothing else.
  connection_env_vars = [
    { name = "BORROWED_HOST", value = var.roster.auth.hostname },
    { name = "BORROWED_PORT", value = tostring(var.roster.auth.port) },
    { name = "BORROWED_NAME", value = var.roster.auth.database },
    { name = "BORROWED_USER", value = var.roster.auth.username },
    { name = "BORROWED_PASSWORD", value = var.roster.auth.password },
    { name = "BORROWED_READ", value = join(",", var.roster.read) },
  ]

  all_env_vars = concat(var.environment_variables, local.connection_env_vars)
}

# A dedicated identity for the running service, separate from the Cloud
# Build identity in the build step. It only ever gets read/pull-level access
# to what this instance is actually connected to.
resource "google_service_account" "runtime" {
  account_id   = local.runtime_sa_id
  display_name = "Cloud Run runtime — ${var.service_name}"
}

resource "google_artifact_registry_repository_iam_member" "runtime_pull" {
  project    = var.gcp_service_account.project_id
  location   = var.container_registry.location
  repository = var.container_registry.name
  role       = [for p in var.container_registry.policies : p.id if p.name == "Pull"][0]
  member     = "serviceAccount:${google_service_account.runtime.email}"
}

resource "google_cloud_run_v2_service" "app" {
  name                = local.service_id
  location            = var.region
  project             = var.gcp_service_account.project_id
  ingress             = var.public_access ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  template {
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = local.image_uri

      resources {
        limits = {
          cpu    = local.size.cpu
          memory = local.size.memory
        }
      }

      dynamic "env" {
        for_each = local.all_env_vars
        content {
          name  = env.value.name
          value = env.value.value
        }
      }
    }

    dynamic "vpc_access" {
      for_each = var.vpc_connector != null ? [1] : []
      content {
        connector = var.vpc_connector.id
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository_iam_member.runtime_pull,
  ]
}

# Cloud Run requires an explicit IAM binding to accept unauthenticated
# requests — there is no such thing as "public" without this. Only created
# when public_access is on, so the default posture is private.
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count    = var.public_access ? 1 : 0
  project  = var.gcp_service_account.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
