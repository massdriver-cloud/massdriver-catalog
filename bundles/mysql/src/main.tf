terraform {
  required_version = ">= 1.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.0"
    }
  }
}

resource "random_pet" "main" {
  keepers = {
    db_version    = var.db_version
    database_name = var.database_name
    network_id    = var.network.data.infrastructure.network_id
  }
}

resource "massdriver_artifact" "database" {
  field                = "database"
  provider_resource_id = random_pet.main.id
  name                 = "Demo MySQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    data = {
      authentication = {
        hostname = "${random_pet.main.id}.mysql.local"
        port     = 3306
        username = "admin"
        password = random_pet.main.id
        database = var.database_name
      }
      infrastructure = {
        id = random_pet.main.id
      }
    }
    specs = {
      database = {
        engine  = "mysql"
        version = var.db_version
      }
    }
  })
}

