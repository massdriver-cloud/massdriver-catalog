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

# The credential is a role to assume, not a key pair. Massdriver's own account is
# the one doing the assuming, and external_id is what the role's trust policy
# checks — leave it off and the assume call is refused.
provider "aws" {
  region = var.region

  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = var.aws_authentication.external_id
  }

  default_tags {
    tags = var.md_metadata.default_tags
  }
}
