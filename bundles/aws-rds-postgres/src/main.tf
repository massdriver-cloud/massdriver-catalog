locals {
  name_prefix        = var.md_metadata.name_prefix
  private_subnet_ids = [for s in var.network.subnets : s.id if s.type == "private"]

  instance_classes = {
    xs = "db.t4g.micro"
    s  = "db.t4g.small"
    m  = "db.t4g.medium"
    l  = "db.t4g.large"
  }
}

resource "random_password" "master" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "main" {
  name_prefix = "${local.name_prefix}-"
  subnet_ids  = local.private_subnet_ids
  tags        = var.md_metadata.default_tags
}

resource "aws_security_group" "db" {
  name_prefix = "${local.name_prefix}-pg-"
  description = "Postgres access from inside the VPC only - never publicly accessible"
  vpc_id      = var.network.vpc_id

  ingress {
    description = "Postgres from the VPC CIDR"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.network.cidr]
  }
  # checkov:skip=CKV_AWS_382: attached to the RDS instance ENI (a managed
  # AWS service, not attacker-controlled compute) — nothing runs here whose
  # egress needs restricting beyond what RDS itself needs.
  egress {
    description = "All outbound - RDS itself, no workload runs here"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-pg" })

  lifecycle {
    create_before_destroy = true
  }
}

# postgresXX parameter group family, matching the major version param.
resource "aws_db_parameter_group" "main" {
  name_prefix = "${local.name_prefix}-"
  family      = "postgres${var.db_version}"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = var.md_metadata.default_tags
}

# Lets RDS push enhanced-monitoring metrics to CloudWatch Logs.
resource "aws_iam_role" "monitoring" {
  name_prefix = "${local.name_prefix}-rds-mon-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "performance_insights" {
  description             = "Encrypts RDS Performance Insights data for ${local.name_prefix}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowRootAccountFullAccess"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
  tags = var.md_metadata.default_tags
}

resource "aws_db_instance" "main" {
  identifier_prefix = "${local.name_prefix}-"
  engine            = "postgres"
  engine_version    = var.db_version
  instance_class    = local.instance_classes[var.instance_size]

  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"
  storage_encrypted = true

  db_name = var.database_name
  # checkov:skip=CKV_AWS_161: this bundle authenticates via username/password
  # by design - the postgres-server resource type's auth contract is
  # hostname/port/database/username/password, and every consuming app in
  # this catalog expects that shape. IAM database authentication would need
  # a different resource type contract (short-lived tokens instead of a
  # static password) and per-app token-refresh logic - a bigger change than
  # a param flip, not something to half-adopt here.
  username = var.username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.main.name
  publicly_accessible    = false

  multi_az                   = var.multi_az
  backup_retention_period    = var.backup_retention_days
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${local.name_prefix}-final"
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  apply_immediately          = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = aws_kms_key.performance_insights.arn

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.monitoring.arn

  tags = var.md_metadata.default_tags
}
