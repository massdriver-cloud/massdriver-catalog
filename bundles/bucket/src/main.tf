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
    bucket_name        = var.bucket_name
    access_level       = var.access_level
    versioning_enabled = tostring(var.versioning_enabled)
    object_lock        = tostring(var.object_lock)
  }
}

locals {
  bucket_name = "${var.bucket_name}-${random_pet.main.id}"
}
