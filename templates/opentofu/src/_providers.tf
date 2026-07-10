terraform {
  required_version = ">= 1.0"
  required_providers {
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.4"
    }
    # Uncomment the provider(s) you need:
    #
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 5.0"
    # }
  }
}

# Uncomment and configure the provider(s) you need. Provider auth fields come
# from the platform credential connection (see platforms/aws/massdriver.yaml):
#
# provider "aws" {
#   region = var.region
#   assume_role {
#     role_arn    = var.aws_authentication.arn
#     external_id = try(var.aws_authentication.external_id, null)
#   }
#   default_tags {
#     tags = var.md_metadata.default_tags
#   }
# }
