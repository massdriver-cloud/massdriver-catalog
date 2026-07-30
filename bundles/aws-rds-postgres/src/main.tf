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
  description = "Postgres access from inside the VPC only — never publicly accessible"
  vpc_id      = var.network.vpc_id

  ingress {
    description = "Postgres from the VPC CIDR"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.network.cidr]
  }
  egress {
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

resource "aws_db_instance" "main" {
  identifier_prefix = "${local.name_prefix}-"
  engine            = "postgres"
  engine_version    = var.db_version
  instance_class    = local.instance_classes[var.instance_size]

  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.database_name
  username = var.username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  multi_az                  = var.multi_az
  backup_retention_period   = var.backup_retention_days
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-final"
  apply_immediately         = true

  tags = var.md_metadata.default_tags
}
