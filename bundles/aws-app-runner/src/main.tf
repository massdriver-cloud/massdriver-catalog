terraform {
  required_version = ">= 1.0"
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
  # Parse CPU and memory values
  cpu_value    = tonumber(split(" ", var.container.cpu)[0])
  memory_value = tonumber(split(" ", var.container.memory)[0])

  # Convert to App Runner format (256, 512, 1024, 2048, 4096 for CPU)
  cpu_map = {
    "0.25" = "256"
    "0.5"  = "512"
    "1"    = "1024"
    "2"    = "2048"
    "4"    = "4096"
  }

  # Convert memory to MB (1 GB = 1024 MB)
  memory_mb = local.memory_value * 1024

  cpu = local.cpu_map[tostring(local.cpu_value)]

  # Build environment variables from params and optional database connection
  base_env = var.container.env != null ? var.container.env : []

  db_env = var.database != null ? [
    {
      name  = "DATABASE_HOST"
      value = var.database.auth.hostname
    },
    {
      name  = "DATABASE_PORT"
      value = tostring(var.database.auth.port)
    },
    {
      name  = "DATABASE_NAME"
      value = var.database.auth.database
    },
    {
      name  = "DATABASE_USER"
      value = var.database.auth.username
    },
    {
      name  = "DATABASE_PASSWORD"
      value = var.database.auth.password
    },
    {
      name  = "DATABASE_URL"
      value = "postgresql://${var.database.auth.username}:${var.database.auth.password}@${var.database.auth.hostname}:${var.database.auth.port}/${var.database.auth.database}"
    }
  ] : []

  all_env = concat(local.base_env, local.db_env)

  min_instances   = try(var.scaling.min_instances, 1)
  max_instances   = try(var.scaling.max_instances, 10)
  max_concurrency = try(var.scaling.max_concurrency, 100)
}

# IAM Role for App Runner instance
resource "aws_iam_role" "instance" {
  name = "${var.md_metadata.name_prefix}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.md_metadata.name_prefix}-instance-role"
  }
}

# IAM Role for App Runner service
resource "aws_iam_role" "access" {
  name = "${var.md_metadata.name_prefix}-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.md_metadata.name_prefix}-access-role"
  }
}

# Attach ECR access policy to access role
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# Auto Scaling Configuration
resource "aws_apprunner_auto_scaling_configuration_version" "main" {
  auto_scaling_configuration_name = var.md_metadata.name_prefix
  min_size                        = local.min_instances
  max_size                        = local.max_instances
  max_concurrency                 = local.max_concurrency

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

# VPC Connector for private VPC access
resource "aws_apprunner_vpc_connector" "main" {
  count = var.vpc != null ? 1 : 0

  vpc_connector_name = var.md_metadata.name_prefix
  subnets            = [for subnet in var.vpc.private_subnets : subnet.id]
  security_groups    = [aws_security_group.app_runner[0].id]

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

# Security Group for App Runner VPC Connector
resource "aws_security_group" "app_runner" {
  count = var.vpc != null ? 1 : 0

  name        = "${var.md_metadata.name_prefix}-app-runner"
  description = "Security group for App Runner VPC connector"
  vpc_id      = var.vpc.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.md_metadata.name_prefix}-app-runner"
  }
}

# App Runner Service
resource "aws_apprunner_service" "main" {
  service_name = var.md_metadata.name_prefix

  source_configuration {
    image_repository {
      image_identifier      = var.container.image
      image_repository_type = "ECR_PUBLIC"

      image_configuration {
        port = tostring(var.container.port)

        runtime_environment_variables = { for env in local.all_env : env.name => env.value }
      }
    }

    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu               = local.cpu
    memory            = tostring(local.memory_mb)
    instance_role_arn = aws_iam_role.instance.arn
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.main.arn

  network_configuration {
    ingress_configuration {
      is_publicly_accessible = var.ingress == "public"
    }

    dynamic "egress_configuration" {
      for_each = var.vpc != null ? [1] : []
      content {
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
    Name = var.md_metadata.name_prefix
  }
}
