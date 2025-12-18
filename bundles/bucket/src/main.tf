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
    bucket_name        = var.bucket_name
    versioning_enabled = tostring(var.versioning_enabled)
  }
}

resource "massdriver_artifact" "bucket" {
  field                = "bucket"
  provider_resource_id = random_pet.main.id
  name                 = "Demo Bucket ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    data = {
      infrastructure = {
        id          = random_pet.main.id
        bucket_name = "${var.bucket_name}-${random_pet.main.id}"
      }
      security = {
        iam = {
          read = {
            policy_id = "${random_pet.main.id}-read"
          }
          write = {
            policy_id = "${random_pet.main.id}-write"
          }
        }
      }
    }
    specs = {
      storage = {
        type = "object-storage"
      }
    }
  })
}

