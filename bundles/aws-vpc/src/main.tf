data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

  # The first sixteenth of the network holds the small public subnets the
  # gateways sit in. The remaining fifteen are what teams are handed, one each.
  # Nothing is built in them here — a team's subnets are created when the team
  # is given a slice, so the network never carves space nobody is using.
  public_prefix = cidrsubnet(var.cidr, 4, 0)
  public_cidrs  = [for i, az in local.azs : cidrsubnet(local.public_prefix, 4, i)]

  team_blocks = [for i in range(1, 16) : cidrsubnet(var.cidr, 4, i)]

  nat_count = var.internet_access == "none" ? 0 : (
    var.internet_access == "nat" ? 1 : var.availability_zone_count
  )
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = var.name }
}

resource "aws_subnet" "public" {
  count = var.availability_zone_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_cidrs[count.index]
  availability_zone = local.azs[count.index]

  # Anything here is deliberately internet-facing, so the public IP is the point.
  # checkov:skip=CKV_AWS_130: NAT gateways and load balancers cannot work without it
  map_public_ip_on_launch = true

  tags = { Name = "${var.name}-public-${local.azs[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-${count.index}" }
}

resource "aws_nat_gateway" "main" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${var.name}-nat-${count.index}" }

  depends_on = [aws_internet_gateway.main]
}

# The default group AWS creates allows everything using it to talk to everything
# else using it. Emptying it means anything that lands on it by accident can do
# nothing at all.
resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-default-deny" }
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = 30

  # checkov:skip=CKV_AWS_158: flow logs record connection metadata, never payloads.
  # A customer managed key here buys no confidentiality and adds a key to rotate.
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name}-vpc-flow-logs"

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
  name = "write-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}
