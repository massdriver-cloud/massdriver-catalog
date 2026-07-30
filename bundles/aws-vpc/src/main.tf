locals {
  name_prefix = var.md_metadata.name_prefix
  azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Carve N public + N private /20s out of the VPC CIDR (16 evenly-sized blocks max).
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.cidr, 4, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.cidr, 4, i + var.az_count)]
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.md_metadata.default_tags, { Name = local.name_prefix })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  # checkov:skip=CKV_AWS_130: this is the public subnet, by definition — an
  # ALB or NAT landing here needs an auto-assigned public IP. Private
  # subnets (below) don't set this.
  map_public_ip_on_launch = true
  tags = merge(var.md_metadata.default_tags, {
    Name                     = "${local.name_prefix}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags = merge(var.md_metadata.default_tags, {
    Name                              = "${local.name_prefix}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Single shared NAT gateway — apps share the cost instead of one-per-AZ.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-nat" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
  tags          = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-nat" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-public" })
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-private" })
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- VPC endpoints: S3 object traffic and ECR image pulls never transit the NAT ---

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-s3" })
}

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${local.name_prefix}-vpce-"
  description = "Allow HTTPS from inside the VPC to interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from the VPC CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr]
  }
  # checkov:skip=CKV_AWS_382: attached to interface endpoint ENIs (a managed
  # AWS service, not attacker-controlled compute) — there's no workload here
  # whose egress needs restricting.
  egress {
    description = "All outbound - no compute runs behind this SG"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-vpce" })

  lifecycle {
    create_before_destroy = true
  }
}

# Every VPC gets a default security group whether you use it or not — lock
# it down so nothing accidentally lands there with an open ruleset.
resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-default-locked" })
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-ecr-api" })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = merge(var.md_metadata.default_tags, { Name = "${local.name_prefix}-ecr-dkr" })
}

# --- Optional flow logs ---

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "flow_logs" {
  count                   = var.enable_flow_logs ? 1 : 0
  description             = "Encrypts VPC flow log group for ${local.name_prefix}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowRootAccountFullAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsToUseTheKey"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*",
          "kms:GenerateDataKey*", "kms:Describe*",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/flowlogs/${local.name_prefix}"
          }
        }
      }
    ]
  })
  tags = var.md_metadata.default_tags
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${local.name_prefix}"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = aws_kms_key.flow_logs[0].arn
}

resource "aws_iam_role" "flow_logs" {
  count       = var.enable_flow_logs ? 1 : 0
  name_prefix = "${local.name_prefix}-flowlogs-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${local.name_prefix}-flowlogs"
  role  = aws_iam_role.flow_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  count           = var.enable_flow_logs ? 1 : 0
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}
