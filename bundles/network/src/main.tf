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
  subnets = [for idx, subnet in var.subnets : {
    id   = "${random_pet.main.id}-${subnet.name}"
    cidr = subnet.cidr
    type = idx == 0 ? "public" : "private"
  }]
}
