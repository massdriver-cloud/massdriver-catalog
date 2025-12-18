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

resource "massdriver_artifact" "bucket" {
  field = "bucket"
  name  = "Demo Bucket ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    data = {
      infrastructure = {
        bucket_id   = random_pet.main.id
        bucket_name = "${var.bucket_name}-${random_pet.main.id}"
      }
      security = {
        policies = local.policies
      }
    }
    specs = {
      storage = {
        type = "object-storage"
      }
    }
  })
}
