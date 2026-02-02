terraform {
  required_version = ">= 1.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

resource "random_pet" "main" {
  keepers = {
    db_version    = var.db_version
    database_name = var.database_name
    username      = var.username
    network_id    = var.network.id
  }
}

locals {
  # Database connection details
  hostname = "${random_pet.main.id}.postgres.local"
  port     = 5432
}
