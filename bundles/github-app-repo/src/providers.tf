terraform {
  required_version = ">= 1.0"
  required_providers {
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Either a token or an App, whichever was imported. The App is preferred — its
# tokens are short-lived and it does not die with an employee — so it wins when
# both happen to be present.
locals {
  use_app = try(var.github.app_id, "") != "" && try(var.github.app_private_key, "") != ""
}

provider "github" {
  owner = var.github.owner
  token = local.use_app ? null : try(var.github.token, null)

  dynamic "app_auth" {
    for_each = local.use_app ? [1] : []
    content {
      id              = var.github.app_id
      installation_id = var.github.app_installation_id
      pem_file        = var.github.app_private_key
    }
  }
}

provider "aws" {
  region = var.registry.region

  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = var.aws_authentication.external_id
  }

  default_tags {
    tags = var.md_metadata.default_tags
  }
}
