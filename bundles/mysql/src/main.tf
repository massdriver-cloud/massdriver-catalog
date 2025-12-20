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
    network_id    = var.network.data.infrastructure.network_id
  }
}

locals {
  # Pick first subnet from network connection and generate IP
  first_subnet_cidr = try(var.network.data.infrastructure.subnets[0].cidr, "10.0.1.0/24")
  first_subnet_id   = try(var.network.data.infrastructure.subnets[0].subnet_id, "subnet-default")
  private_ip        = cidrhost(local.first_subnet_cidr, 20)

  # Database connection details
  hostname = "${random_pet.main.id}.mysql.local"
  port     = 3306

  # Example access policies
  policies = [
    {
      name   = "read"
      policy = "reader"
    },
    {
      name   = "write"
      policy = "writer"
    },
    {
      name   = "admin"
      policy = "admin"
    }
  ]
}

resource "massdriver_artifact" "database" {
  field = "database"
  name  = "Demo MySQL ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    data = {
      authentication = {
        hostname = "${random_pet.main.id}.mysql.local"
        port     = 3306
        username = var.username
        password = random_pet.main.id
        database = var.database_name
      }
      infrastructure = {
        database_id = random_pet.main.id
        subnet_id   = local.first_subnet_id
        private_ip  = local.private_ip
      }
      security = {
        policies = local.policies
      }
    }
    specs = {
      database = {
        engine   = "mysql"
        version  = var.db_version
        hostname = local.hostname
        port     = local.port
        username = var.username
      }
      network = {
        subnet_id  = local.first_subnet_id
        private_ip = local.private_ip
      }
    }
  })
}
