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
    bucket_name        = var.bucket_name
    versioning_enabled = tostring(var.versioning_enabled)
  }
}

locals {
  bucket_name = "${var.bucket_name}-${random_pet.main.id}"
}
