resource "massdriver_artifact" "database" {
  field = "database"
  name  = "Demo MySQL ${var.md_metadata.name_prefix}"
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
