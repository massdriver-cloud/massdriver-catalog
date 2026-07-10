terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.4"
    }
  }
}

# Requires an `aws_authentication` connection with $ref: aws-iam-role.
# Add it when scaffolding, or under `connections:` in massdriver.yaml.
provider "aws" {
  region = var.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}
