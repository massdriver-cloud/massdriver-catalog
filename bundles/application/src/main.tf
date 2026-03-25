terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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

provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

locals {
  name_prefix = var.md_metadata.name_prefix
}

# -----------------------------------------------------------------------------
# Application Security Group
#
# Every application gets its own security group. This is the identity used
# to establish network connectivity with other resources (like MariaDB)
# via security group rules — not CIDR blocks.
# -----------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  description = "Security group for application ${local.name_prefix}"
  vpc_id      = var.aws_vpc.id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-app"
  }
}

# -----------------------------------------------------------------------------
# MariaDB Processor
#
# This submodule demonstrates how artifact connections carry security and
# compliance metadata between bundles. It:
#   1. Binds the application's SG to the MariaDB SG (network access)
#   2. References the Secrets Manager ARN (credential access)
#   3. Outputs connection details for demo purposes
# -----------------------------------------------------------------------------

module "mariadb_processor" {
  source = "./modules/mariadb-processor"

  name_prefix                   = local.name_prefix
  database                      = var.database
  application_security_group_id = aws_security_group.app.id
}

# -----------------------------------------------------------------------------
# Application placeholder
# -----------------------------------------------------------------------------

resource "random_pet" "main" {
  keepers = {
    image      = var.image
    replicas   = tostring(var.replicas)
    port       = tostring(var.port)
    network_id = var.aws_vpc.id
    database   = var.database.auth.hostname
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "application_id" {
  value       = random_pet.main.id
  description = "Demo application identifier"
}

output "config" {
  value = {
    image    = var.image
    replicas = var.replicas
    port     = var.port
  }
  description = "Application configuration"
}

# --- Demo outputs from mariadb-processor (illustrative only) ---

output "mariadb_connection" {
  value = {
    hostname            = module.mariadb_processor.database_hostname
    username            = module.mariadb_processor.database_username
    security_group_id   = module.mariadb_processor.database_security_group_id
    secrets_manager_arn = module.mariadb_processor.database_secrets_manager_arn
    access_granted      = module.mariadb_processor.security_group_rule_description
  }
  description = "⚠️  DEMO ONLY — Shows artifact data flowing from MariaDB bundle to application. Never output credentials in production."
}
