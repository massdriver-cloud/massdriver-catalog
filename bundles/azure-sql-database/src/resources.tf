resource "massdriver_resource" "database" {
  field = "database"
  name  = "SQL Database ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id   = azurerm_mssql_database.main.id
    tier = var.sku

    auth = {
      hostname = azurerm_mssql_server.main.fully_qualified_domain_name
      port     = 1433
      database = azurerm_mssql_database.main.name
      username = var.username
      password = random_password.admin.result
    }

    policies = [
      {
        id   = "db_datareader"
        name = "Read"
      },
      {
        id   = "db_datawriter"
        name = "Read and write"
      },
      {
        id   = "db_owner"
        name = "Full control"
      }
    ]
  })
}
