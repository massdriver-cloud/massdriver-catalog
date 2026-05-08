locals {
  public_subnet_artifacts = [for idx, id in module.vpc.public_subnets : {
    id                = id
    cidr              = module.vpc.public_subnets_cidr_blocks[idx]
    availability_zone = local.azs[idx]
    type              = "public"
  }]

  private_subnet_artifacts = [for idx, id in module.vpc.private_subnets : {
    id                = id
    cidr              = module.vpc.private_subnets_cidr_blocks[idx]
    availability_zone = local.azs[idx]
    type              = "private"
  }]

  subnet_artifacts = concat(local.public_subnet_artifacts, local.private_subnet_artifacts)
}

resource "massdriver_artifact" "vpc" {
  field = "vpc"
  name  = "AWS VPC ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id         = module.vpc.vpc_id
    arn        = module.vpc.vpc_arn
    cidr       = module.vpc.vpc_cidr_block
    region     = var.region
    account_id = data.aws_caller_identity.current.account_id
    subnets    = local.subnet_artifacts
    security_group_ids = {
      default   = module.vpc.default_security_group_id
      endpoints = aws_security_group.endpoints.id
    }
  })
}
