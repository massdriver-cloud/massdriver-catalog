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
  region = var.vpc.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

# Generate a secure random password
resource "random_password" "master" {
  length  = 32
  special = false
}

# Get the latest minor version for the selected major version
data "aws_rds_engine_version" "postgres" {
  engine       = "postgres"
  version      = var.db_version
  default_only = true
}

# DB subnet group using selected subnets
resource "aws_db_subnet_group" "main" {
  name       = var.md_metadata.name_prefix
  subnet_ids = var.subnet_ids

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

# Security group for RDS
resource "aws_security_group" "main" {
  name        = "${var.md_metadata.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc.id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc.cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.md_metadata.name_prefix}-rds-sg"
  }
}

# RDS PostgreSQL instance (no replicas)
resource "aws_db_instance" "main" {
  identifier = var.md_metadata.name_prefix

  engine         = "postgres"
  engine_version = data.aws_rds_engine_version.postgres.version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.main.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = "sun:05:00-sun:06:00"

  skip_final_snapshot        = true
  delete_automated_backups   = true
  deletion_protection        = false
  auto_minor_version_upgrade = true

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

locals {
  hostname = aws_db_instance.main.endpoint
  port     = aws_db_instance.main.port
}
