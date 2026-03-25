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
    external_id = var.aws_authentication.external_id
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

locals {
  name_prefix = var.md_metadata.name_prefix

  # Private subnets preferred; fall back to all subnets
  private_subnet_ids = length([
    for s in var.aws_vpc.subnets : s.id if try(s.type, "") == "private"
    ]) > 0 ? [
    for s in var.aws_vpc.subnets : s.id if try(s.type, "") == "private"
  ] : [for s in var.aws_vpc.subnets : s.id]

  # Auth token: only valid when transit encryption is enabled
  auth_token_enabled = var.auth_token_enabled && var.transit_encryption_enabled

  # Parameter group family maps from engine version
  # Redis 7.x uses "redis7", 6.x uses "redis6.x"
  parameter_group_family = startswith(var.engine_version, "7") ? "redis7" : "redis6.x"

  # Use-case-specific parameter tuning
  # caching: allow eviction (allkeys-lru), no persistence
  # session:  no eviction (noeviction), keep data safe
  # pubsub:   allow eviction, no persistence needed
  maxmemory_policy = var.use_case == "session" ? "noeviction" : "allkeys-lru"
}

# -----------------------------------------------------------------------------
# Auth Token (stored in Secrets Manager when enabled)
# -----------------------------------------------------------------------------

resource "random_password" "auth_token" {
  count = local.auth_token_enabled ? 1 : 0

  length  = 64
  special = false # ElastiCache auth tokens cannot contain @, ", /
}

resource "aws_secretsmanager_secret" "auth_token" {
  count = local.auth_token_enabled ? 1 : 0

  name_prefix = "${local.name_prefix}-redis-auth-token-"
  description = "Redis AUTH token for ${local.name_prefix}"
  kms_key_id  = aws_kms_key.redis.arn

  tags = {
    Name = "${local.name_prefix}-redis-auth-token"
  }
}

resource "aws_secretsmanager_secret_version" "auth_token" {
  count = local.auth_token_enabled ? 1 : 0

  secret_id     = aws_secretsmanager_secret.auth_token[0].id
  secret_string = random_password.auth_token[0].result
}

# -----------------------------------------------------------------------------
# KMS Key for encryption at rest
# -----------------------------------------------------------------------------

resource "aws_kms_key" "redis" {
  description             = "KMS key for ElastiCache Redis - ${local.name_prefix}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${local.name_prefix}-redis-kms"
  }
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${local.name_prefix}-redis"
  target_key_id = aws_kms_key.redis.key_id
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "redis" {
  name_prefix = "${local.name_prefix}-redis-"
  description = "Security group for ElastiCache Redis ${local.name_prefix}"
  vpc_id      = var.aws_vpc.id

  ingress {
    description = "Redis access from within VPC"
    from_port   = var.port
    to_port     = var.port
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
    Name = "${local.name_prefix}-redis"
  }
}

# -----------------------------------------------------------------------------
# Subnet Group
# -----------------------------------------------------------------------------

resource "aws_elasticache_subnet_group" "main" {
  name        = "${local.name_prefix}-redis"
  description = "Subnet group for ElastiCache Redis ${local.name_prefix}"
  subnet_ids  = local.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}

# -----------------------------------------------------------------------------
# Parameter Group (use-case tuned)
# -----------------------------------------------------------------------------

resource "aws_elasticache_parameter_group" "main" {
  name        = "${local.name_prefix}-redis"
  family      = local.parameter_group_family
  description = "Parameter group for Redis ${var.engine_version} (${var.use_case}) - ${local.name_prefix}"

  parameter {
    name  = "maxmemory-policy"
    value = local.maxmemory_policy
  }

  # Pub/sub: increase notify-keyspace-events to track expiry and keyspace events
  dynamic "parameter" {
    for_each = var.use_case == "pubsub" ? [1] : []
    content {
      name  = "notify-keyspace-events"
      value = "Ex"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}

# -----------------------------------------------------------------------------
# Replication Group (single-node or multi-node)
# -----------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis ${var.use_case} cluster - ${local.name_prefix}"

  # Engine
  engine             = "redis"
  engine_version     = var.engine_version
  node_type          = var.node_type
  num_cache_clusters = var.num_cache_clusters
  port               = var.port

  # Network
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # Parameter group
  parameter_group_name = aws_elasticache_parameter_group.main.name

  # Encryption
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  kms_key_id                 = var.at_rest_encryption_enabled ? aws_kms_key.redis.arn : null
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = local.auth_token_enabled ? random_password.auth_token[0].result : null

  # High Availability
  automatic_failover_enabled = var.num_cache_clusters > 1 ? var.automatic_failover_enabled : false
  multi_az_enabled           = var.num_cache_clusters > 1 ? var.multi_az_enabled : false

  # Snapshots
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = try(var.maintenance.snapshot_window, "03:00-04:00")

  # Maintenance
  maintenance_window         = try(var.maintenance.preferred_maintenance_window, "sun:05:00-sun:06:00")
  auto_minor_version_upgrade = try(var.maintenance.auto_minor_version_upgrade, true)
  apply_immediately          = var.apply_immediately

  tags = {
    Name    = "${local.name_prefix}-redis"
    UseCase = var.use_case
  }

  depends_on = [
    aws_elasticache_subnet_group.main,
    aws_security_group.redis,
    aws_elasticache_parameter_group.main,
  ]
}
