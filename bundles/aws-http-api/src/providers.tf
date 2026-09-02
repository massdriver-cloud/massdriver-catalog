terraform {
  required_version = ">= 1.0"
  required_providers {
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.landing_zone.network.region

  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = var.aws_authentication.external_id
  }

  default_tags {
    tags = var.md_metadata.default_tags
  }
}
