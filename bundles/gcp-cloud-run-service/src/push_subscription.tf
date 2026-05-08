# ─── Pub/Sub Push Subscription ────────────────────────────────────────────────
#
# This file is active only when `incoming_topic` is wired on the canvas.
# It creates everything needed for Pub/Sub to authenticate and invoke this
# Cloud Run service via HTTP push.
#
# TWO SERVICE ACCOUNT PATTERN
# ───────────────────────────
# This uses two separate service accounts with distinct purposes:
#
#   google_service_account.runtime  (created in main.tf)
#     ↳ The identity the container RUNS AS. It holds IAM bindings for
#       Pub/Sub publisher, BigQuery, GCS, etc. — resources the app accesses.
#       DO NOT use this SA for the push subscription OIDC token.
#
#   google_service_account.push_invoker  (created in THIS file)
#     ↳ The identity Pub/Sub uses to INVOKE the Cloud Run service via HTTP.
#       It is granted only roles/run.invoker on this specific service.
#       Pub/Sub attaches an OIDC token for this SA to each push request,
#       which Cloud Run validates before passing the request to the container.
#
# Separating these SAs means a compromised push subscription token cannot be
# used to publish messages or access data resources, and the runtime SA cannot
# be used to forge push deliveries from other topics.
#
# FLOW
# ────
# Pub/Sub publishes a message to incoming_topic
#   → Pub/Sub's push delivery thread attaches an OIDC token for push_invoker SA
#   → Cloud Run validates the token → roles/run.invoker check passes
#   → Request is routed to the container (running as the runtime SA)
#   → Container processes the message and returns 2xx to acknowledge

# ─── Push Invoker Service Account ─────────────────────────────────────────────
# A dedicated SA used exclusively by Pub/Sub to OIDC-authenticate push requests.
# account_id is capped at 30 chars (GCP limit). We use a "-p" suffix to
# distinguish it from the runtime SA that shares the same name_prefix.

resource "google_service_account" "push_invoker" {
  count = var.incoming_topic != null ? 1 : 0

  project      = local.project_id
  account_id   = "${substr(local.name_prefix, 0, 28)}-p"
  display_name = "Pub/Sub Push Invoker — ${local.name_prefix}"
  description  = "Used by Pub/Sub to invoke Cloud Run service ${local.name_prefix} via OIDC push. Managed by Massdriver."
}

# ─── Grant push_invoker SA run.invoker on THIS service ────────────────────────
# Scoped to this specific Cloud Run service — not a project-level binding.
# This is the minimal permission Pub/Sub needs to successfully deliver messages.

resource "google_cloud_run_v2_service_iam_member" "push_invoker" {
  count = var.incoming_topic != null ? 1 : 0

  project  = local.project_id
  location = local.region
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.push_invoker[0].email}"
}

# ─── Pub/Sub Push Subscription ────────────────────────────────────────────────
# Subscribes to incoming_topic and delivers messages to this service's URL.
#
# push_endpoint: the service's root URI (provided by the Cloud Run v2 API).
#   Append a path (e.g., /events) in the service code or override push_endpoint
#   to a path — Pub/Sub appends nothing by default.
#
# oidc_token: Pub/Sub attaches a signed OIDC token for push_invoker SA on every
#   request. Cloud Run validates the token and checks run.invoker before routing.
#   audience defaults to the push_endpoint URL, which is the correct value for
#   Cloud Run OIDC validation.
#
# ack_deadline_seconds: if the service does not return 2xx within this window,
#   Pub/Sub redelivers the message. Max is 600s. Long-running handlers must either
#   acknowledge early (return 2xx, then process async) or stay well under the limit.
#
# retry_policy: exponential backoff between redeliveries. 10s minimum and 600s
#   maximum are sensible defaults for most event-driven workloads. Tune if your
#   downstream has specific rate constraints.

resource "google_pubsub_subscription" "push" {
  count = var.incoming_topic != null ? 1 : 0

  project = var.incoming_topic.project_id
  name    = "${local.name_prefix}-push"
  topic   = var.incoming_topic.topic_id

  ack_deadline_seconds = var.push_ack_deadline_seconds

  push_config {
    push_endpoint = google_cloud_run_v2_service.main.uri

    oidc_token {
      service_account_email = google_service_account.push_invoker[0].email
      # audience defaults to push_endpoint — correct for Cloud Run OIDC validation
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  labels = var.md_metadata.default_tags
}
