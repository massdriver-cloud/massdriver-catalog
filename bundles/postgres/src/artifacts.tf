resource "massdriver_artifact" "database" {
  field = "database"
  name  = "Demo PostgreSQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    connection = {
      hostname = local.hostname
      port     = local.port
      database = var.database_name
      username = var.username
      password = random_pet.main.id
    }
    infrastructure = {
      database_id = random_pet.main.id
    }
  })
}
