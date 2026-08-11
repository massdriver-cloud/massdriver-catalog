resource "massdriver_resource" "database" {
  field = "database"
  name  = "PostgreSQL ${google_sql_database_instance.main.name}"

  resource = jsonencode({
    id                = google_sql_database_instance.main.connection_name
    version           = var.postgres_version
    high_availability = var.keep_running_if_a_zone_fails

    auth = {
      hostname = google_sql_database_instance.main.private_ip_address
      port     = 5432
      database = google_sql_database.app.name
      username = google_sql_user.app.name
      password = random_password.app.result
    }

    # `policies` exposes the IAM role a consumer's own service account needs
    # in order to reach this instance (e.g. via the Cloud SQL Auth Proxy or
    # IAM database authentication). This bundle only publishes the role id —
    # the actual binding is created by the consuming bundle against its own
    # service account, e.g.:
    #
    #   resource "google_project_iam_member" "runtime_cloudsql_client" {
    #     project = var.gcp_service_account.project_id
    #     role    = [for p in var.database.policies : p.id if p.name == "Connect to this database"][0]
    #     member  = "serviceAccount:${google_service_account.runtime.email}"
    #   }
    policies = [
      {
        id   = "roles/cloudsql.client"
        name = "Connect to this database"
      }
    ]
  })
}
