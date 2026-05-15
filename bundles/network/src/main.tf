terraform {
  required_version = ">= 1.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.4"
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
    id   = "${random_pet.main.id}-${subnet.name}"
    cidr = subnet.cidr
    type = try(subnet.type, "private")
  }]
}
