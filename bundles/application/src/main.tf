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

locals {
  has_database = var.database != null
  has_bucket   = var.bucket != null
}

resource "random_pet" "main" {
  keepers = {
    image      = var.image
    replicas   = tostring(var.replicas)
    port       = tostring(var.port)
    network_id = var.network.data.infrastructure.network_id
    database   = local.has_database ? var.database.data.authentication.hostname : "none"
    bucket     = local.has_bucket ? var.bucket.data.infrastructure.bucket_name : "none"
  }
}

output "application_id" {
  value       = random_pet.main.id
  description = "Demo application identifier"
}

output "config" {
  value = {
    image    = var.image
    replicas = var.replicas
    port     = var.port
  }
  description = "Application configuration"
}
