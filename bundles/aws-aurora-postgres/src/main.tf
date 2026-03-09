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
  region = var.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

# Generate random password
resource "random_password" "main" {
  length  = 32
  special = false
}

locals {
  multi_az         = try(var.availability.multi_az, false)
  min_acu          = try(var.capacity.min_acu, 0.5)
  max_acu          = try(var.capacity.max_acu, 1)
  retention_days   = try(var.backup.retention_days, 7)
  engine_version   = var.engine_version
  postgres_version = split(".", var.engine_version)[0]

  # Get private subnet IDs from VPC artifact
  private_subnet_ids = [for subnet in var.vpc.private_subnets : subnet.id]
}

# KMS key for encryption at rest
resource "aws_kms_key" "main" {
  description             = "Aurora cluster encryption key for ${var.md_metadata.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.md_metadata.name_prefix}-aurora-key"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.md_metadata.name_prefix}-aurora"
  target_key_id = aws_kms_key.main.key_id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = var.md_metadata.name_prefix
  subnet_ids = local.private_subnet_ids

  tags = {
    Name = "${var.md_metadata.name_prefix}-subnet-group"
  }
}

# Security Group for Aurora
resource "aws_security_group" "main" {
  name        = "${var.md_metadata.name_prefix}-aurora"
  description = "Security group for Aurora cluster ${var.md_metadata.name_prefix}"
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
    Name = "${var.md_metadata.name_prefix}-aurora-sg"
  }
}

# IAM role for Enhanced Monitoring
resource "aws_iam_role" "monitoring" {
  name = "${var.md_metadata.name_prefix}-aurora-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.md_metadata.name_prefix}-aurora-monitoring"
  }
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier                  = var.md_metadata.name_prefix
  engine                              = "aurora-postgresql"
  engine_mode                         = "provisioned"
  engine_version                      = local.engine_version
  database_name                       = var.database_name
  master_username                     = var.username
  master_password                     = random_password.main.result
  db_subnet_group_name                = aws_db_subnet_group.main.name
  vpc_security_group_ids              = [aws_security_group.main.id]
  backup_retention_period             = local.retention_days
  preferred_backup_window             = "03:00-04:00"
  storage_encrypted                   = true
  kms_key_id                          = aws_kms_key.main.arn
  skip_final_snapshot                 = true
  apply_immediately                   = true
  copy_tags_to_snapshot               = true
  iam_database_authentication_enabled = true

  serverlessv2_scaling_configuration {
    min_capacity = local.min_acu
    max_capacity = local.max_acu
  }

  enabled_cloudwatch_logs_exports = [
    "postgresql"
  ]

  tags = {
    Name = "${var.md_metadata.name_prefix}-cluster"
  }
}

# Aurora Instance
resource "aws_rds_cluster_instance" "main" {
  count                        = local.multi_az ? 2 : 1
  identifier                   = "${var.md_metadata.name_prefix}-${count.index}"
  cluster_identifier           = aws_rds_cluster.main.id
  instance_class               = "db.serverless"
  engine                       = aws_rds_cluster.main.engine
  engine_version               = aws_rds_cluster.main.engine_version
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.monitoring.arn
  performance_insights_enabled = true
  apply_immediately            = true

  tags = {
    Name = "${var.md_metadata.name_prefix}-instance-${count.index}"
  }
}
