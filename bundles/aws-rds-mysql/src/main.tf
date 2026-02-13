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
data "aws_rds_engine_version" "mysql" {
  engine       = "mysql"
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
  description = "Security group for RDS MySQL"
  vpc_id      = var.vpc.id

  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
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

# Parameter group for MySQL with SSL and logging
resource "aws_db_parameter_group" "main" {
  name   = var.md_metadata.name_prefix
  family = "mysql${var.db_version}"

  # CKV2_AWS_69: Require SSL/TLS connections
  parameter {
    name  = "require_secure_transport"
    value = "1"
  }

  # Enable general and slow query logs
  parameter {
    name  = "general_log"
    value = "1"
  }

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "1"
  }

  parameter {
    name  = "log_output"
    value = "FILE"
  }

  tags = var.md_metadata.default_tags
}

# IAM role for enhanced monitoring
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

# RDS MySQL instance
# checkov:skip=CKV_AWS_161:IAM database auth not supported by most applications
# checkov:skip=CKV_AWS_293:Deletion protection exposed as user param
# checkov:skip=CKV_AWS_157:Multi-AZ exposed as user param for cost control
resource "aws_db_instance" "main" {
  identifier = var.md_metadata.name_prefix

  engine         = "mysql"
  engine_version = data.aws_rds_engine_version.mysql.version
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
  multi_az               = var.multi_az

  parameter_group_name = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = "sun:05:00-sun:06:00"

  copy_tags_to_snapshot = true

  skip_final_snapshot      = true
  delete_automated_backups = true

  deletion_protection = var.deletion_protection

  auto_minor_version_upgrade = true

  # Enable CloudWatch logs export for MySQL
  enabled_cloudwatch_logs_exports = ["general", "slowquery", "error"]

  # Enable enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.enhanced_monitoring.arn

  # Enable Performance Insights (not supported on db.t3.micro)
  performance_insights_enabled          = !startswith(var.instance_class, "db.t3.micro")
  performance_insights_retention_period = startswith(var.instance_class, "db.t3.micro") ? null : 7

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

locals {
  hostname = aws_db_instance.main.endpoint
  port     = aws_db_instance.main.port
}
