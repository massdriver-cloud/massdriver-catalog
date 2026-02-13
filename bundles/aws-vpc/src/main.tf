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

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.md_metadata.name_prefix
  }
}

# CKV2_AWS_12: Restrict default security group to prevent accidental use
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress or egress rules - forces explicit security group usage
  tags = {
    Name = "${var.md_metadata.name_prefix}-default-restricted"
  }
}

# CKV2_AWS_11: Enable VPC flow logging for security auditing
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.md_metadata.name_prefix}/flow-logs"
  retention_in_days = 14

  tags = var.md_metadata.default_tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.md_metadata.name_prefix}-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = var.md_metadata.default_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.md_metadata.name_prefix}-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  iam_role_arn             = aws_iam_role.flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  max_aggregation_interval = 60

  tags = {
    Name = "${var.md_metadata.name_prefix}-flow-log"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.md_metadata.name_prefix}-igw"
  }
}

resource "aws_subnet" "main" {
  for_each = { for subnet in var.subnets : subnet.name => subnet }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = "${var.region}${each.value.availability_zone}"
  map_public_ip_on_launch = each.value.type == "public"

  tags = {
    Name = "${var.md_metadata.name_prefix}-${each.key}"
    Type = each.value.type
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.md_metadata.name_prefix}-public-rt"
  }
}

# Route table for private subnets (no internet route)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.md_metadata.name_prefix}-private-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  for_each = { for subnet in var.subnets : subnet.name => subnet if subnet.type == "public" }

  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  for_each = { for subnet in var.subnets : subnet.name => subnet if subnet.type == "private" }

  subnet_id      = aws_subnet.main[each.key].id
  route_table_id = aws_route_table.private.id
}

locals {
  subnets = [for subnet in var.subnets : {
    id                = aws_subnet.main[subnet.name].id
    arn               = aws_subnet.main[subnet.name].arn
    cidr              = subnet.cidr
    name              = subnet.name
    availability_zone = "${var.region}${subnet.availability_zone}"
    type              = subnet.type
  }]
}
