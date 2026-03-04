terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
  service_name = var.md_metadata.name_prefix
  has_vpc      = var.vpc != null
  has_database = var.database != null

  # Build environment variables
  base_env = try(var.container.env, [])
  db_env = local.has_database ? [
    { name = "DATABASE_HOST", value = var.database.auth.hostname },
    { name = "DATABASE_PORT", value = tostring(var.database.auth.port) },
    { name = "DATABASE_NAME", value = var.database.auth.database },
    { name = "DATABASE_USER", value = var.database.auth.username },
    { name = "DATABASE_PASSWORD", value = var.database.auth.password },
    { name = "DATABASE_URL", value = "postgresql://${var.database.auth.username}:${var.database.auth.password}@${var.database.auth.hostname}:${var.database.auth.port}/${var.database.auth.database}" }
  ] : []
  all_env = concat(local.base_env, local.db_env)

  cpu    = try(var.container.cpu, "1024")
  memory = try(var.container.memory, "2048")
}

# IAM Role for App Runner to access ECR
resource "aws_iam_role" "access_role" {
  name = "${local.service_name}-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.service_name}-access-role"
  }
}

resource "aws_iam_role_policy_attachment" "access_role_ecr" {
  role       = aws_iam_role.access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# IAM Role for App Runner instance
resource "aws_iam_role" "instance_role" {
  name = "${local.service_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.service_name}-instance-role"
  }
}

# VPC Connector (if VPC provided)
resource "aws_apprunner_vpc_connector" "main" {
  count = local.has_vpc ? 1 : 0

  vpc_connector_name = local.service_name
  subnets            = [for subnet in var.vpc.private_subnets : subnet.id]
  security_groups    = [aws_security_group.app_runner[0].id]

  tags = {
    Name = "${local.service_name}-vpc-connector"
  }
}

# Security Group for VPC Connector
resource "aws_security_group" "app_runner" {
  count = local.has_vpc ? 1 : 0

  name        = "${local.service_name}-app-runner-sg"
  description = "Security group for App Runner VPC connector"
  vpc_id      = var.vpc.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.service_name}-app-runner-sg"
  }
}

# Auto Scaling Configuration
resource "aws_apprunner_auto_scaling_configuration_version" "main" {
  auto_scaling_configuration_name = local.service_name

  min_size        = try(var.scaling.min_instances, 1)
  max_size        = try(var.scaling.max_instances, 10)
  max_concurrency = try(var.scaling.max_concurrency, 100)

  tags = {
    Name = "${local.service_name}-autoscaling"
  }
}

# App Runner Service
resource "aws_apprunner_service" "main" {
  service_name = local.service_name

  source_configuration {
    auto_deployments_enabled = false

    image_repository {
      image_identifier      = var.container.image
      image_repository_type = startswith(var.container.image, "public.ecr.aws") ? "ECR_PUBLIC" : (can(regex("^[0-9]+\\.dkr\\.ecr\\.", var.container.image)) ? "ECR" : "ECR_PUBLIC")

      image_configuration {
        port                          = tostring(try(var.container.port, 8080))
        runtime_environment_variables = { for env in local.all_env : env.name => env.value }
      }
    }

    authentication_configuration {
      access_role_arn = startswith(var.container.image, "public.ecr.aws") ? null : aws_iam_role.access_role.arn
    }
  }

  instance_configuration {
    cpu               = local.cpu
    memory            = local.memory
    instance_role_arn = aws_iam_role.instance_role.arn
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.main.arn

  dynamic "network_configuration" {
    for_each = local.has_vpc ? [1] : []
    content {
      egress_configuration {
        egress_type       = "VPC"
        vpc_connector_arn = aws_apprunner_vpc_connector.main[0].arn
      }
    }
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  tags = {
    Name = local.service_name
  }
}
