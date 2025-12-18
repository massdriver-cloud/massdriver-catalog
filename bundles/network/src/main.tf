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
    cidr    = var.cidr
    subnets = jsonencode(var.subnets)
  }
}

locals {
  subnets = [for subnet in var.subnets : {
    subnet_id = "${random_pet.main.id}-${subnet.name}"
    cidr      = subnet.cidr
  }]
}

resource "massdriver_artifact" "network" {
  field = "network"
  name  = "Demo Network ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    data = {
      infrastructure = {
        network_id = random_pet.main.id
        cidr       = var.cidr
        subnets    = local.subnets
      }
    }
    specs = {
      network = {
        cidr = var.cidr
      }
    }
  })
}
