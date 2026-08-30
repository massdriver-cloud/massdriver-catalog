resource "massdriver_resource" "dataset" {
  field = "dataset"
  name  = "BigQuery ${google_bigquery_dataset.analytics.dataset_id}"

  resource = jsonencode({
    id         = google_bigquery_dataset.analytics.id
    project_id = var.gcp_service_account.project_id
    dataset_id = google_bigquery_dataset.analytics.dataset_id
    location   = google_bigquery_dataset.analytics.location

    # The dotted form, ready to paste into EXTERNAL_QUERY. The three-field
    # version of this is on the canvas too; nobody should have to reassemble it.
    connection_id = local.external_query_connection

    source_database = {
      database = var.analytics_login.auth.database
      username = var.analytics_login.auth.username
    }

    federated_tables = local.federated_tables

    # Policy `id` is the GCP IAM role a consuming bundle binds to its own
    # service account — e.g. a dashboard or a scheduled report that queries
    # this dataset rather than a person in the console:
    #
    #   resource "google_project_iam_member" "reports_job_user" {
    #     project = var.gcp_service_account.project_id
    #     role    = [for p in var.dataset.policies : p.id if p.name == "Run queries"][0]
    #     member  = "serviceAccount:${google_service_account.runtime.email}"
    #   }
    #
    # A workload that queries the app tables needs all three: one to start the
    # job, one to read the dataset, one to use the connection.
    policies = [
      {
        id   = "roles/bigquery.jobUser"
        name = "Run queries"
      },
      {
        id   = "roles/bigquery.dataViewer"
        name = "Read this dataset"
      },
      {
        id   = "roles/bigquery.connectionUser"
        name = "Read the app database through this connection"
      }
    ]
  })
}
