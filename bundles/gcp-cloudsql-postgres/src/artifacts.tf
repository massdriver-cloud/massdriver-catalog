resource "massdriver_artifact" "database" {
  field = "database"
  name  = "Cloud SQL PostgreSQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    auth = {
      hostname = google_sql_database_instance.main.private_ip_address
      port     = 5432
      database = var.database_name
      username = var.username
      password = random_password.main.result
    }
    id      = google_sql_database_instance.main.id
    version = local.postgres_version_num
    policies = [
      {
        id   = "read-only"
        name = "Read"
      },
      {
        id   = "read-write"
        name = "Write"
      },
      {
        id   = "admin"
        name = "Admin"
      }
    ]
  })
}
