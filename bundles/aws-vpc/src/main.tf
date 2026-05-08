data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = var.md_metadata.name_prefix
  azs  = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

  public_subnets  = [for idx, az in local.azs : cidrsubnet(var.cidr, 4, idx)]
  private_subnets = [for idx, az in local.azs : cidrsubnet(var.cidr, 4, idx + var.availability_zone_count)]

  enable_nat_gateway = var.nat_gateway_mode != "none"
  single_nat_gateway = var.nat_gateway_mode == "single"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = local.name
  cidr = var.cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway   = local.enable_nat_gateway
  single_nat_gateway   = local.single_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = true

  enable_flow_log                      = var.enable_flow_logs
  create_flow_log_cloudwatch_log_group = var.enable_flow_logs
  create_flow_log_cloudwatch_iam_role  = var.enable_flow_logs
  flow_log_max_aggregation_interval    = 60

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  manage_default_network_acl  = true
  default_network_acl_ingress = []
  default_network_acl_egress  = []
  manage_default_route_table  = true
  default_route_table_routes  = []

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    Tier                     = "public"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    Tier                              = "private"
  }
}

resource "aws_security_group" "endpoints" {
  # checkov:skip=CKV2_AWS_5: This SG is published as an artifact for downstream
  # bundles (RDS, EKS) to attach to. It is intentionally unattached at the time
  # this VPC bundle deploys.
  name_prefix = "${local.name}-endpoints-"
  description = "Security group for VPC interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from inside the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  # Restrict egress to VPC CIDR (was 0.0.0.0/0 — failed CKV_AWS_382). For
  # workloads that need to call AWS services through this SG, prefer
  # interface endpoints (private DNS) so traffic stays inside the VPC.
  egress {
    description = "Egress to inside the VPC only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  tags = {
    Name = "${local.name}-endpoints"
  }
}
