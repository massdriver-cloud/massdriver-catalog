resource "massdriver_resource" "database" {
  field = "database"
  name  = "PostgreSQL ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id                = aws_db_instance.main.arn
    version           = var.db_version
    high_availability = var.high_availability
    auth = {
      hostname = aws_db_instance.main.address
      port     = 5432
      database = var.database_name
      username = var.username
      password = random_password.main.result
    }
    policies = [
      {
        id   = "read-only"
        name = "Read"
      },
      {
        id   = "read-write"
        name = "Write"
      },
    ]
  })
}
