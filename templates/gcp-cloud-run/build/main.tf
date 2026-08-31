# Builds the app's container image inside GCP via Cloud Build and pushes it to
# the connected Artifact Registry. Nobody needs docker or gcloud on their
# machine — this step archives the source, uploads it, and runs the build.
#
# The deploy step (../deploy) independently re-derives the exact same image
# tag from md_metadata.package.deployment_enqueued_at rather than reading an
# output from this step's state. That's deliberate: the two steps don't share
# Terraform state, and md_metadata is identical across every step of the same
# deployment, so both sides land on the same tag without passing anything
# between them.
#
# Why this isn't a simple google_cloudbuild_trigger: creating/updating a
# trigger only registers its definition with Cloud Build — it does not run it.
# There is no provisioner-free, synchronous "submit a build and block until
# done" resource in the Google provider (a confirmed, known gap, not a
# guess), and this bundle's provisioner cannot shell out to `gcloud builds
# submit --wait`. So: keep a real google_cloudbuild_trigger as the durable,
# inspectable build definition, invoke it directly over Cloud Build's REST
# API with the credentials Terraform already has, wait a bounded amount of
# time, then verify the image actually landed in Artifact Registry before
# letting the deploy step proceed. If it didn't land, this step fails loudly
# with a link to the build log, instead of silently handing the deploy step a
# tag that doesn't exist.
locals {
  # Docker tags can't contain ':'; strip it rather than the whole timestamp so
  # tags stay ordered and traceable to the deployment that produced them.
  image_tag = lower(replace(var.md_metadata.package.deployment_enqueued_at, ":", "-"))
  image_uri = "${var.container_registry.registry_url}/${var.service_name}:${local.image_tag}"

  # google_service_account.account_id is capped at 30 characters; name_prefix
  # alone can exceed that once project/environment/component names are long.
  build_sa_id = trimsuffix(substr("cb-${var.md_metadata.name_prefix}", 0, 30), "-")

  sources_bucket_name = trimsuffix(substr("build-src-${var.md_metadata.name_prefix}", 0, 63), "-")
  source_object_name  = "source/${local.image_tag}.zip"

  # Generous headroom for a cold Cloud Build worker plus a small Python image
  # build/push. There's no way to end the wait early on success (see the
  # comment above), so this trades a few wasted minutes on the happy path for
  # never racing the deploy step against an unfinished build.
  build_wait_seconds = 480
}

resource "google_project_service" "cloudbuild" {
  project            = var.gcp_service_account.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "storage" {
  project            = var.gcp_service_account.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# A dedicated identity for the build itself, separate from the Cloud Run
# runtime identity in the deploy step. The build only ever needs to push one
# image and write its own logs — it should never hold whatever permissions
# the running service ends up with.
resource "google_service_account" "cloud_build" {
  account_id   = local.build_sa_id
  display_name = "Cloud Build — ${var.service_name}"
}

resource "google_project_iam_member" "cloud_build_logs" {
  project = var.gcp_service_account.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

resource "google_artifact_registry_repository_iam_member" "cloud_build_push" {
  project    = var.gcp_service_account.project_id
  location   = var.container_registry.location
  repository = var.container_registry.name
  role       = [for p in var.container_registry.policies : p.id if p.name == "Push and Pull"][0]
  member     = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Running a trigger that's configured with a custom service_account requires
# the CALLER (the identity behind data.google_client_config.current below) to
# be able to act as that service account — not just the service account
# itself needing permissions. Without this, invoking the trigger fails with a
# bare 403 PERMISSION_DENIED that gives no hint this is the missing piece.
resource "google_service_account_iam_member" "caller_can_act_as_build_sa" {
  service_account_id = google_service_account.cloud_build.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.gcp_service_account.client_email}"
}

# The application source lives in ./app. Zipping it locally with the archive
# provider is a plain, declarative file operation — not a shell-out — so it's
# allowed under this bundle's provisioner constraints.
data "archive_file" "app_source" {
  type        = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/.build/${local.image_tag}.zip"
}

resource "google_storage_bucket" "sources" {
  name                        = local.sources_bucket_name
  location                    = var.region
  project                     = var.gcp_service_account.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  versioning {
    enabled = true
  }

  # Source archives are only needed for the build that consumes them. Keep a
  # short trail for debugging a failed build, then let them age out — this
  # also covers noncurrent versions, so turning on versioning above doesn't
  # accumulate storage forever.
  lifecycle_rule {
    condition {
      age = 14
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age        = 14
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_object" "app_source" {
  name   = local.source_object_name
  bucket = google_storage_bucket.sources.name
  source = data.archive_file.app_source.output_path
}

# Cloud Build reads the source archive as itself (the trigger's
# service_account), not as whatever identity created the object — without
# this, resolving the build's source fails with a storage.objects.get 403,
# distinct from (and downstream of) the actAs permission above.
resource "google_storage_bucket_iam_member" "cloud_build_read_source" {
  bucket = google_storage_bucket.sources.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloud_build.email}"
}

# google_cloudbuild_trigger requires one of {github, pubsub_config,
# source_to_build, trigger_template, webhook_config, bitbucket_server_...} —
# Terraform's provider cannot create a truly manual-only trigger (see
# hashicorp/terraform-provider-google#16295). This topic exists solely to
# satisfy that requirement; nothing ever publishes to it, so it never fires
# the trigger on its own. The trigger is invoked directly below instead.
resource "google_pubsub_topic" "unused_trigger_requirement" {
  name = "cb-manual-${var.md_metadata.name_prefix}"
}

resource "google_cloudbuild_trigger" "build" {
  name     = trimsuffix(substr("build-${var.md_metadata.name_prefix}", 0, 64), "-")
  location = "global"

  pubsub_config {
    topic = google_pubsub_topic.unused_trigger_requirement.id
  }

  service_account = "projects/${var.gcp_service_account.project_id}/serviceAccounts/${google_service_account.cloud_build.email}"

  build {
    source {
      storage_source {
        bucket = google_storage_bucket.sources.name
        object = google_storage_bucket_object.app_source.name
      }
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "-t", local.image_uri, "."]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.image_uri]
    }

    images = [local.image_uri]

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  depends_on = [
    google_project_service.cloudbuild,
    google_artifact_registry_repository_iam_member.cloud_build_push,
    google_project_iam_member.cloud_build_logs,
    google_service_account_iam_member.caller_can_act_as_build_sa,
    google_storage_bucket_iam_member.cloud_build_read_source,
  ]
}

# Bearer token for the two direct REST calls below, using the same identity
# Terraform is already authenticated as.
data "google_client_config" "current" {}

# Cloud Build triggers only run in response to their configured event source
# (here, an unused pubsub topic — see above) or a direct :run call. This is
# that call: run the trigger we just defined, using its own stored source and
# build config.
data "http" "run_build" {
  url    = "https://cloudbuild.googleapis.com/v1/projects/${var.gcp_service_account.project_id}/triggers/${google_cloudbuild_trigger.build.trigger_id}:run"
  method = "POST"

  request_headers = {
    Authorization = "Bearer ${data.google_client_config.current.access_token}"
    Content-Type  = "application/json"
  }
  request_body = jsonencode({})

  depends_on = [google_storage_bucket_object.app_source, google_cloudbuild_trigger.build]

  lifecycle {
    postcondition {
      condition     = contains([200, 201], self.status_code)
      error_message = "Failed to start Cloud Build (HTTP ${self.status_code}): ${self.response_body}"
    }
  }
}

# There is no provisioner-free way to poll Cloud Build's own build-status API
# until it flips from WORKING to SUCCESS (it always returns HTTP 200,
# regardless of build status, so the http provider's retry-on-status-code
# can't distinguish "still building" from "done"). Instead: wait a bounded
# duration, then check for the one thing that actually matters — whether the
# tagged image exists in Artifact Registry, which the registry API reports
# with a 404 until it's really there.
resource "time_sleep" "wait_for_build" {
  create_duration = "${local.build_wait_seconds}s"

  # Without `triggers`, this resource only actually sleeps on the very first
  # deploy — once it exists in state, a plain `depends_on` on a data source
  # gives Terraform no reason to recreate (and thus re-wait) it on later
  # applies, even though run_build kicked off a brand-new build. Keying
  # triggers on the image tag (unique per deployment) forces a fresh sleep
  # every time.
  triggers = {
    image_tag = local.image_tag
  }

  depends_on = [data.http.run_build]
}

# Purely diagnostic: the trigger's :run response is a long-running Operation
# whose metadata embeds the Build it created (metadata.build.id). Read that
# specific build back after the wait so a failure below can report the
# build's actual status and log link, instead of forcing whoever's debugging
# to hunt for the right build in the console by hand.
data "http" "build_status" {
  url    = "https://cloudbuild.googleapis.com/v1/projects/${var.gcp_service_account.project_id}/builds/${jsondecode(data.http.run_build.response_body).metadata.build.id}"
  method = "GET"

  request_headers = {
    Authorization = "Bearer ${data.google_client_config.current.access_token}"
  }

  depends_on = [time_sleep.wait_for_build]
}

data "http" "verify_image" {
  url    = "https://artifactregistry.googleapis.com/v1/${var.container_registry.id}/packages/${var.service_name}/tags/${local.image_tag}"
  method = "GET"

  request_headers = {
    Authorization = "Bearer ${data.google_client_config.current.access_token}"
  }

  depends_on = [time_sleep.wait_for_build]

  lifecycle {
    postcondition {
      condition = self.status_code == 200
      error_message = join(" ", [
        "Cloud Build did not produce ${local.image_uri} within ${local.build_wait_seconds}s.",
        "Build status: ${try(jsondecode(data.http.build_status.response_body).status, "unknown")}.",
        "Build log: ${try(jsondecode(data.http.build_status.response_body).logUrl, "https://console.cloud.google.com/cloud-build/builds?project=${var.gcp_service_account.project_id}")}",
      ])
    }
  }
}
