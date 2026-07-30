resource "massdriver_resource" "database" {
  field = "database"
  name  = "Postgres (${var.md_metadata.name_prefix})"
  resource = jsonencode({
    id                = aws_db_instance.main.id
    engine            = "rds-postgres"
    version           = var.db_version
    region            = var.network.region
    high_availability = var.multi_az
    auth = {
      hostname = aws_db_instance.main.address
      port     = aws_db_instance.main.port
      database = var.database_name
      username = var.username
      password = random_password.master.result
    }
  })
}
