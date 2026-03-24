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
  region = local.region
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
  region      = var.region

  # Private subnets preferred for RDS; fall back to all subnets if none tagged private
  private_subnet_ids = length([
    for s in var.aws_vpc.subnets : s.id if try(s.type, "") == "private"
    ]) > 0 ? [
    for s in var.aws_vpc.subnets : s.id if try(s.type, "") == "private"
  ] : [for s in var.aws_vpc.subnets : s.id]

  # Enhanced monitoring: create IAM role only if interval > 0
  enhanced_monitoring_enabled = var.monitoring.enhanced_monitoring_interval > 0

  # Max allocated storage: 0 means disable autoscaling (pass null to AWS provider)
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
}

# -----------------------------------------------------------------------------
# Password
# -----------------------------------------------------------------------------

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store password in SSM Parameter Store for operational access
resource "aws_ssm_parameter" "master_password" {
  name        = "/${local.name_prefix}/mariadb/master-password"
  description = "MariaDB master password for ${local.name_prefix}"
  type        = "SecureString"
  value       = random_password.master.result

  tags = {
    Name = "${local.name_prefix}-mariadb-master-password"
  }
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-mariadb-"
  description = "Security group for MariaDB RDS instance ${local.name_prefix}"
  vpc_id      = var.aws_vpc.id

  ingress {
    description = "MariaDB access from within VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc.cidr]
  }

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
    Name = "${local.name_prefix}-mariadb"
  }
}

# -----------------------------------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name_prefix = "${local.name_prefix}-mariadb-"
  description = "Subnet group for MariaDB RDS instance ${local.name_prefix}"
  subnet_ids  = local.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-mariadb"
  }
}

# -----------------------------------------------------------------------------
# KMS Key for encryption at rest
# -----------------------------------------------------------------------------

resource "aws_kms_key" "rds" {
  description             = "KMS key for MariaDB RDS encryption - ${local.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${local.name_prefix}-mariadb-kms"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-mariadb"
  target_key_id = aws_kms_key.rds.key_id
}

# -----------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring (created only if interval > 0)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "rds_monitoring_assume" {
  count = local.enhanced_monitoring_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  count = local.enhanced_monitoring_enabled ? 1 : 0

  name_prefix        = "${local.name_prefix}-rds-monitoring-"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume[0].json

  tags = {
    Name = "${local.name_prefix}-rds-monitoring"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = local.enhanced_monitoring_enabled ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# -----------------------------------------------------------------------------
# DB Parameter Group (MariaDB-specific tuning)
# -----------------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  name_prefix = "${local.name_prefix}-mariadb-"
  family      = "mariadb${var.engine_version}"
  description = "Parameter group for MariaDB ${var.engine_version} - ${local.name_prefix}"

  # Keep parameter group clean initially; parameters can be added after instance creation
  parameter {
    name         = "character_set_server"
    value        = "utf8mb4"
    apply_method = "immediate"
  }

  parameter {
    name         = "collation_server"
    value        = "utf8mb4_unicode_ci"
    apply_method = "immediate"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-mariadb"
  }
}

# -----------------------------------------------------------------------------
# DB Option Group
# -----------------------------------------------------------------------------

resource "aws_db_option_group" "main" {
  name_prefix              = "${local.name_prefix}-mariadb-"
  option_group_description = "Option group for MariaDB ${var.engine_version} - ${local.name_prefix}"
  engine_name              = "mariadb"
  major_engine_version     = var.engine_version

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-mariadb"
  }
}

# -----------------------------------------------------------------------------
# RDS Instance
# -----------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier_prefix = "${local.name_prefix}-mariadb-"

  # Engine
  engine         = "mariadb"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage
  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = local.max_allocated_storage
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # Database
  db_name  = var.database_name
  username = var.username
  password = random_password.master.result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3306

  # High Availability
  multi_az = var.multi_az

  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.main.name
  option_group_name    = aws_db_option_group.main.name

  # Backups
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.maintenance.preferred_backup_window
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-mariadb-final-snapshot"
  delete_automated_backups  = false

  # Maintenance
  maintenance_window         = var.maintenance.preferred_maintenance_window
  auto_minor_version_upgrade = var.maintenance.auto_minor_version_upgrade
  apply_immediately          = false

  # Monitoring
  monitoring_interval = var.monitoring.enhanced_monitoring_interval
  monitoring_role_arn = local.enhanced_monitoring_enabled ? aws_iam_role.rds_monitoring[0].arn : null

  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? aws_kms_key.rds.arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  # Protection
  deletion_protection = var.deletion_protection

  # IAM database authentication (best practice)
  iam_database_authentication_enabled = true

  tags = {
    Name = "${local.name_prefix}-mariadb"
  }

  depends_on = [
    aws_db_subnet_group.main,
    aws_security_group.rds,
    aws_db_parameter_group.main,
    aws_db_option_group.main,
  ]
}

# -----------------------------------------------------------------------------
# Read Replica (only created when multi_az is true for HA read scaling)
# This is a read replica in the same region. For a true cross-AZ read endpoint
# in MariaDB, the multi_az standby already handles failover; we add a read
# replica for read scale-out.
# -----------------------------------------------------------------------------

# NOTE: We always output a "reader" artifact. When multi_az is false we point
# it at the same instance endpoint (which is correct for dev/small deployments).
# When multi_az is true we create an actual read replica.

resource "aws_db_instance" "reader" {
  count = var.multi_az ? 1 : 0

  identifier_prefix = "${local.name_prefix}-mariadb-reader-"

  replicate_source_db = aws_db_instance.main.identifier
  instance_class      = var.instance_class

  # Storage encryption inherits from source
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # Network
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  port                   = 3306

  # Parameter group (must be same family)
  parameter_group_name = aws_db_parameter_group.main.name

  # No backups on replica
  backup_retention_period  = 0
  skip_final_snapshot      = true
  delete_automated_backups = true

  # Maintenance
  maintenance_window         = var.maintenance.preferred_maintenance_window
  auto_minor_version_upgrade = var.maintenance.auto_minor_version_upgrade
  apply_immediately          = false

  # Monitoring
  monitoring_interval = var.monitoring.enhanced_monitoring_interval
  monitoring_role_arn = local.enhanced_monitoring_enabled ? aws_iam_role.rds_monitoring[0].arn : null

  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? aws_kms_key.rds.arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  # Protection — replicas should also be protected in prod
  deletion_protection = var.deletion_protection

  iam_database_authentication_enabled = true

  tags = {
    Name = "${local.name_prefix}-mariadb-reader"
    Role = "read-replica"
  }

  depends_on = [aws_db_instance.main]
}

# -----------------------------------------------------------------------------
# Locals for artifact hostnames
# -----------------------------------------------------------------------------

locals {
  writer_hostname = aws_db_instance.main.address
  reader_hostname = var.multi_az ? aws_db_instance.reader[0].address : aws_db_instance.main.address
}
