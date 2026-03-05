resource "massdriver_artifact" "database" {
  field = "database"
  name  = "Aurora PostgreSQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    auth = {
      hostname = aws_rds_cluster.main.endpoint
      port     = 5432
      database = var.database_name
      username = var.username
      password = random_password.main.result
    }
    id      = aws_rds_cluster.main.id
    version = local.postgres_version
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
