resource "massdriver_artifact" "database" {
  field = "database"
  name  = "Demo PostgreSQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    auth = {
      hostname = local.hostname
      port     = local.port
      database = var.database_name
      username = var.username
      password = random_pet.main.id
    }
    id      = random_pet.main.id
    version = var.db_version
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
