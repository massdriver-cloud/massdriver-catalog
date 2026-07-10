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
      version = "~> 1.4"
    }
  }
}

provider "aws" {
  region = var.network.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

locals {
  # T-shirt sizes from the form map to concrete instance classes here.
  instance_classes = {
    xs = "db.t4g.micro"
    s  = "db.t4g.small"
    m  = "db.t4g.medium"
    l  = "db.r6g.large"
  }
  instance_class = local.instance_classes[var.instance_size]

  # Databases belong on private subnets; fall back to all subnets only if the
  # connected network has no private tier.
  private_subnet_ids = [for s in var.network.subnets : s.id if s.tier == "private"]
  subnet_group_ids   = length(local.private_subnet_ids) > 0 ? local.private_subnet_ids : [for s in var.network.subnets : s.id]

  # AZ of the subnet picked in the placement_subnet dropdown. Only used to pin
  # the primary when high availability is off — Multi-AZ ignores AZ pinning.
  placement_az = try(one([for s in var.network.subnets : s.availability_zone if s.id == var.placement_subnet]), null)
}

resource "aws_db_subnet_group" "main" {
  name       = var.md_metadata.name_prefix
  subnet_ids = local.subnet_group_ids

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

resource "aws_security_group" "main" {
  name        = var.md_metadata.name_prefix
  description = "PostgreSQL access for ${var.md_metadata.name_prefix}"
  vpc_id      = var.network.vpc_id

  ingress {
    description = "PostgreSQL from inside the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.network.cidr]
  }

  # No egress rules: RDS never initiates outbound connections.

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

resource "random_password" "main" {
  length  = 32
  special = false # letters and digits only, so the password is safe inside connection URIs
}

resource "aws_db_instance" "main" {
  identifier     = var.md_metadata.name_prefix
  engine         = "postgres"
  engine_version = var.db_version # major version only; AWS tracks the latest minor
  instance_class = local.instance_class

  db_name  = var.database_name
  username = var.username
  password = random_password.main.result

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.storage_autoscaling ? var.max_storage_gb : null
  storage_encrypted     = true

  multi_az          = var.high_availability
  availability_zone = var.high_availability ? null : local.placement_az

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.main.id]
  publicly_accessible    = false

  backup_retention_period = var.backup_retention_days

  skip_final_snapshot = true  # demo catalog — flip to false (and set final_snapshot_identifier) for real use
  deletion_protection = false # demo catalog — enable when this holds data you can't lose
  apply_immediately   = true  # demo responsiveness — real production changes should wait for the maintenance window
}
