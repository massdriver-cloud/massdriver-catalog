resource "massdriver_artifact" "database" {
  field = "database"
  name  = "Aurora PostgreSQL ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    id = aws_rds_cluster.main.id
    auth = {
      hostname = aws_rds_cluster.main.endpoint
      port     = 5432
      database = var.database_name
      username = var.username
      password = random_password.master.result
    }
  })
}
