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
  # T-shirt sizes map to instance classes; the UI never asks for a class name.
  instance_classes = {
    xs = "db.t4g.micro"
    s  = "db.t4g.small"
    m  = "db.t4g.medium"
    l  = "db.r6g.large"
  }
  instance_class = local.instance_classes[var.instance_size]

  # Prefer private subnets; fall back to all subnets if the network has none.
  private_subnet_ids = [for s in var.network.subnets : s.id if s.tier == "private"]
  db_subnet_ids      = length(local.private_subnet_ids) > 0 ? local.private_subnet_ids : [for s in var.network.subnets : s.id]

  parameter_group_family = "mariadb${var.db_version}"

  db_parameters = concat(
    [
      { name = "character_set_server", value = var.character_set },
      { name = "collation_server", value = var.collation },
    ],
    var.slow_query_log_enabled ? [
      { name = "slow_query_log", value = "1" },
      { name = "long_query_time", value = tostring(var.slow_query_log_seconds) },
    ] : []
  )
}

resource "aws_db_subnet_group" "main" {
  name       = var.md_metadata.name_prefix
  subnet_ids = local.db_subnet_ids

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

resource "aws_security_group" "main" {
  name        = var.md_metadata.name_prefix
  description = "MariaDB access for ${var.md_metadata.name_prefix}: port 3306 from inside the VPC only"
  vpc_id      = var.network.vpc_id

  ingress {
    description = "MariaDB from the VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.network.cidr]
  }

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

resource "aws_db_parameter_group" "main" {
  name   = var.md_metadata.name_prefix
  family = local.parameter_group_family

  dynamic "parameter" {
    for_each = local.db_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

# URI-safe password: no special characters, so connection strings need no escaping.
resource "random_password" "main" {
  length  = 32
  special = false
}

resource "aws_db_instance" "main" {
  identifier     = var.md_metadata.name_prefix
  engine         = "mariadb"
  engine_version = var.db_version

  instance_class    = local.instance_class
  allocated_storage = var.allocated_storage_gb
  multi_az          = var.high_availability

  db_name  = var.database_name
  username = var.username
  password = random_password.main.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.main.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_days
  storage_encrypted       = true
  publicly_accessible     = false

  # Demo catalog: tear-downs should be instant. Flip both for real use.
  skip_final_snapshot = true
  deletion_protection = false

  # Demo catalog: apply changes right away instead of waiting for the
  # maintenance window, so the demo feels responsive.
  apply_immediately = true

  tags = {
    Name = var.md_metadata.name_prefix
  }
}
