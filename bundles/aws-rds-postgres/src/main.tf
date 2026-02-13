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
# checkov:skip=CKV_AWS_382:RDS requires outbound for AWS API calls, enhanced monitoring, and log shipping
# checkov:skip=CKV2_AWS_5:Security group is attached to RDS instance below
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

# CKV2_AWS_30: Parameter group for PostgreSQL query logging
# CKV2_AWS_69: Enforce SSL/TLS encryption in transit
resource "aws_db_parameter_group" "main" {
  name   = var.md_metadata.name_prefix
  family = "postgres${var.db_version}"

  # CKV2_AWS_69: Force SSL connections for encryption in transit
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # Enable query logging for security auditing and performance analysis
  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking more than 1 second
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = var.md_metadata.default_tags
}

# CKV_AWS_118: IAM role for enhanced monitoring
resource "aws_iam_role" "enhanced_monitoring" {
  name = "${var.md_metadata.name_prefix}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.md_metadata.default_tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  role       = aws_iam_role.enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
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

  # CKV2_AWS_30: Use parameter group with query logging
  parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = "sun:05:00-sun:06:00"

  # CKV2_AWS_60: Copy tags to snapshots for traceability
  copy_tags_to_snapshot = true

  skip_final_snapshot      = true
  delete_automated_backups = true

  # CKV_AWS_293: Enable deletion protection (configurable)
  deletion_protection = var.deletion_protection

  auto_minor_version_upgrade = true

  # CKV_AWS_129: Enable CloudWatch logs export
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # CKV_AWS_118: Enable enhanced monitoring (60 second interval)
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.enhanced_monitoring.arn

  # CKV_AWS_353: Enable Performance Insights (free tier: 7 days)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

locals {
  hostname = aws_db_instance.main.endpoint
  port     = aws_db_instance.main.port
}
