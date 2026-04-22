# Optional: receive messages from a Pub/Sub topic via push subscription.
#
# If you picked a gcp-pubsub-topic connection named `incoming_topic` at scaffold
# time, uncomment the resources below. This creates a push subscription that
# invokes this service's URL using OIDC with a dedicated invoker SA.
#
# The push invoker SA is separate from this service's runtime SA. Pub/Sub uses
# the invoker SA to call the service; the runtime SA is the identity the
# container runs as once the request lands.
#
# resource "google_service_account" "push_invoker" {
#   project      = local.project_id
#   account_id   = "${substr(local.name_prefix, 0, 28)}-p"
#   display_name = "Push Invoker — ${local.name_prefix}"
# }
#
# resource "google_cloud_run_v2_service_iam_member" "push_invoker" {
#   project  = local.project_id
#   location = google_cloud_run_v2_service.main.location
#   name     = google_cloud_run_v2_service.main.name
#   role     = "roles/run.invoker"
#   member   = "serviceAccount:${google_service_account.push_invoker.email}"
# }
#
# resource "google_pubsub_subscription" "push" {
#   project = var.incoming_topic.project_id
#   name    = "${local.name_prefix}-push"
#   topic   = var.incoming_topic.topic_id
#
#   ack_deadline_seconds = 60
#
#   push_config {
#     push_endpoint = google_cloud_run_v2_service.main.uri
#     oidc_token {
#       service_account_email = google_service_account.push_invoker.email
#     }
#   }
#
#   retry_policy {
#     minimum_backoff = "10s"
#     maximum_backoff = "600s"
#   }
# }
