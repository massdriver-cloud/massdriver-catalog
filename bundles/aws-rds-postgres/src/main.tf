data "aws_caller_identity" "current" {}

locals {
  name            = var.md_metadata.name_prefix
  identifier      = substr(replace(local.name, "_", "-"), 0, 60)
  private_subnets = [for s in var.vpc.subnets : s.id if s.type == "private"]
  family          = "postgres${var.engine_version}"
  use_master_pw   = var.master_password != null && var.master_password != ""
  manage_password = !local.use_master_pw
}

resource "random_password" "master" {
  count   = local.manage_password ? 1 : 0
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.identifier}-subnets"
  subnet_ids = local.private_subnets

  tags = {
    Name = "${local.identifier}-subnets"
  }
}

resource "aws_security_group" "db" {
  name_prefix = "${local.identifier}-db-"
  description = "Security group for RDS instance ${local.identifier}"
  vpc_id      = var.vpc.id

  tags = {
    Name = "${local.identifier}-db"
  }
}

resource "aws_security_group_rule" "db_ingress_vpc" {
  description       = "PostgreSQL traffic from inside the VPC"
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [var.vpc.cidr]
  security_group_id = aws_security_group.db.id
}

resource "aws_security_group_rule" "db_egress_https" {
  description       = "RDS managed plumbing reaches AWS APIs over HTTPS"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db.id
}

resource "aws_db_parameter_group" "main" {
  name_prefix = "${local.identifier}-"
  family      = local.family
  description = "Parameter group for ${local.identifier}"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "main" {
  identifier     = local.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.username
  password = local.use_master_pw ? var.master_password : random_password.master[0].result

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  multi_az                            = var.multi_az
  publicly_accessible                 = false
  iam_database_authentication_enabled = var.iam_database_auth

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-05:00"
  maintenance_window      = "sun:05:30-sun:06:30"

  copy_tags_to_snapshot     = true
  delete_automated_backups  = false
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${local.identifier}-final" : null

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  auto_minor_version_upgrade = true

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = local.identifier
  }
}

resource "aws_db_instance" "replica" {
  count = var.read_replica_count

  identifier          = "${local.identifier}-r${count.index + 1}"
  replicate_source_db = aws_db_instance.main.identifier
  instance_class      = var.instance_class

  storage_encrypted = var.storage_encrypted

  publicly_accessible                 = false
  iam_database_authentication_enabled = var.iam_database_auth

  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  skip_final_snapshot        = true

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = "${local.identifier}-r${count.index + 1}"
  }
}

# Reader endpoint: when replicas exist we use the first replica's address.
# Production setups typically front replicas with an Aurora reader endpoint
# or external load balancer; for instance-class Postgres this is the simplest
# pattern.
locals {
  reader_endpoint = var.read_replica_count > 0 ? aws_db_instance.replica[0].address : null
}

# Enhanced monitoring role
data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name_prefix        = "rds-mon-"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Master credential storage in Secrets Manager
resource "aws_secretsmanager_secret" "master" {
  name_prefix             = "rds/${local.identifier}-"
  description             = "Master credentials for RDS instance ${local.identifier}"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = local.use_master_pw ? var.master_password : random_password.master[0].result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}
