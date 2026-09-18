resource "massdriver_resource" "database" {
  field = "database"
  name  = "Cosmos DB ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id          = azurerm_cosmosdb_account.main.id
    name        = azurerm_cosmosdb_account.main.name
    database    = var.database_name
    api         = var.api
    consistency = var.consistency

    auth = {
      endpoint      = azurerm_cosmosdb_account.main.endpoint
      primary_key   = azurerm_cosmosdb_account.main.primary_key
      read_only_key = azurerm_cosmosdb_account.main.primary_readonly_key
    }
  })

  depends_on = [
    azurerm_cosmosdb_sql_database.main,
    azurerm_cosmosdb_mongo_database.main,
  ]
}
