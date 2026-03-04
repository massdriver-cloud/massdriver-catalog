terraform {
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
  region = var.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

locals {
  cluster_name = var.md_metadata.name_prefix
  min_capacity = try(var.capacity.min_capacity, 0.5)
  max_capacity = try(var.capacity.max_capacity, 4)
}

# Random password for database
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${local.cluster_name}-subnet-group"
  subnet_ids = [for subnet in var.vpc.private_subnets : subnet.id]

  tags = {
    Name = "${local.cluster_name}-subnet-group"
  }
}

# Security Group
resource "aws_security_group" "aurora" {
  name        = "${local.cluster_name}-aurora-sg"
  description = "Security group for Aurora PostgreSQL cluster"
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
    Name = "${local.cluster_name}-aurora-sg"
  }
}

# KMS Key for encryption
resource "aws_kms_key" "aurora" {
  description             = "KMS key for Aurora PostgreSQL encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${local.cluster_name}-aurora-kms"
  }
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${local.cluster_name}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

# Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier = local.cluster_name
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.username
  master_password    = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  storage_encrypted = true
  kms_key_id        = aws_kms_key.aurora.arn

  backup_retention_period = try(var.backup.retention_days, 7)
  preferred_backup_window = "03:00-04:00"
  copy_tags_to_snapshot   = true

  deletion_protection = var.deletion_protection

  serverlessv2_scaling_configuration {
    min_capacity = local.min_capacity
    max_capacity = local.max_capacity
  }

  enabled_cloudwatch_logs_exports = ["postgresql"]

  skip_final_snapshot = true

  tags = {
    Name = local.cluster_name
  }
}

# Aurora Instance (Serverless v2)
resource "aws_rds_cluster_instance" "main" {
  identifier         = "${local.cluster_name}-instance-1"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.aurora.arn

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = "${local.cluster_name}-instance-1"
  }
}

# Enhanced Monitoring IAM Role
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.cluster_name}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.cluster_name}-rds-monitoring"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
