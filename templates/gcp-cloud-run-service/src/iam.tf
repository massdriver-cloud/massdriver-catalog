# Grant this service's runtime SA the minimum role it needs on each upstream
# resource it consumes. Each connection you picked at scaffold time is available
# as var.<connection_name>.
#
# Examples — uncomment and adapt based on which connections you selected:
#
# resource "google_pubsub_topic_iam_member" "publisher" {
#   project = var.pubsub_topic.project_id
#   topic   = var.pubsub_topic.topic_name
#   role    = "roles/pubsub.publisher"
#   member  = local.runtime_sa_member
# }
#
# resource "google_bigquery_dataset_iam_member" "data_editor" {
#   project    = var.bigquery_dataset.project_id
#   dataset_id = var.bigquery_dataset.dataset_id
#   role       = "roles/bigquery.dataEditor"
#   member     = local.runtime_sa_member
# }
#
# resource "google_storage_bucket_iam_member" "object_user" {
#   bucket = var.storage_bucket.bucket_name
#   role   = "roles/storage.objectUser"
#   member = local.runtime_sa_member
# }
