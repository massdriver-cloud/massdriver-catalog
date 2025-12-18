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
    cidr    = var.cidr
    subnets = jsonencode(var.subnets)
  }
}

resource "massdriver_artifact" "network" {
  field                = "network"
  provider_resource_id = random_pet.main.id
  name                 = "Demo Network ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    data = {
      infrastructure = {
        network_id = random_pet.main.id
        cidr       = var.cidr
        subnets    = [for subnet in var.subnets : "${random_pet.main.id}-${subnet.name}"]
      }
    }
    specs = {
      network = {
        cidr = var.cidr
      }
    }
  })
}

