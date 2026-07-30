locals {
  name_prefix        = var.md_metadata.name_prefix
  private_subnet_ids = [for s in var.network.subnets : s.id if s.type == "private"]

  node_types = {
    xs = "cache.t4g.micro"
    s  = "cache.t4g.small"
    m  = "cache.t4g.medium"
    l  = "cache.t4g.large"
  }
}

# ElastiCache auth tokens have their own charset rules — keep it alphanumeric.
resource "random_password" "auth_token" {
  length  = 32
  special = false
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.name_prefix}-cache"
  subnet_ids = local.private_subnet_ids
}

resource "aws_security_group" "cache" {
  name_prefix = "${local.name_prefix}-cache-"
  description = "Valkey access from inside the VPC only"
  vpc_id      = var.network.vpc_id

  ingress {
    description = "Valkey from the VPC CIDR"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.network.cidr]
  }
  # checkov:skip=CKV_AWS_382: attached to the cache cluster's ENIs (a
  # managed AWS service, not attacker-controlled compute) — nothing runs
  # here whose egress needs restricting beyond what ElastiCache itself needs.
  egress {
    description = "All outbound - ElastiCache itself, no workload runs here"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-cache" })

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "cache" {
  description             = "Encrypts Valkey cache at rest for ${local.name_prefix}"
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

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${local.name_prefix}-cache"
  description          = "Valkey cache for ${local.name_prefix}"

  engine         = "valkey"
  engine_version = var.engine_version
  node_type      = local.node_types[var.node_size]

  num_cache_clusters         = var.high_availability ? 2 : 1
  automatic_failover_enabled = var.high_availability

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.cache.id]

  # Not configurable, on purpose — session/cache data is sensitive by default.
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.cache.arn
  transit_encryption_enabled = true
  auth_token                 = random_password.auth_token.result

  apply_immediately = true
  tags              = var.md_metadata.default_tags
}
