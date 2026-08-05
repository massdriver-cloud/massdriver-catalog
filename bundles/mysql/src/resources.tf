resource "massdriver_resource" "database" {
  field = "database"
  name  = "Demo MySQL ${var.md_metadata.name_prefix}"
  resource = jsonencode({
    auth = {
      hostname = local.hostname
      port     = local.port
      database = var.database_name
      username = var.username
      password = random_pet.main.id
    }
    id                = random_pet.main.id
    version           = var.db_version
    character_set     = var.character_set
    high_availability = var.high_availability
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
