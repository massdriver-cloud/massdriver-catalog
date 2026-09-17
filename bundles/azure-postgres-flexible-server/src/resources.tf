resource "massdriver_resource" "database" {
  field = "database"
  name  = "PostgreSQL ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id = azurerm_postgresql_flexible_server.main.id

    auth = {
      hostname = azurerm_postgresql_flexible_server.main.fqdn
      port     = 5432
      database = azurerm_postgresql_flexible_server_database.main.name
      username = var.username
      password = random_password.admin.result
    }

    version           = var.db_version
    high_availability = var.high_availability

    policies = [
      {
        id   = "read-only"
        name = "Read"
      },
      {
        id   = "read-write"
        name = "Read and write"
      },
      {
        id   = "admin"
        name = "Full control"
      }
    ]
  })
}
