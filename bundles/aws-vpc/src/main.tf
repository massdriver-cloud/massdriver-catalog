terraform {
  required_version = ">= 1.0"
  required_providers {
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

# NOTE: Simulated resources. The aws-vpc bundle's real-TF variant uses
# `terraform-aws-modules/vpc/aws` to provision a real VPC, NAT, IGW, subnets,
# locked-down default SG/NACL, and flow logs. It is currently disabled
# because this AWS account hits `VpcLimitExceeded` in every region tested
# (us-west-2, us-east-1). When the per-region VPC quota is bumped, restore
# the real-TF version from git history.

resource "random_pet" "vpc" {
  length = 2
  keepers = {
    cidr   = var.cidr
    azs    = tostring(var.availability_zone_count)
    region = var.region
  }
}

locals {
  account_id = "123456789012"
  vpc_id     = "vpc-${substr(md5(random_pet.vpc.id), 0, 17)}"

  azs = slice(["${var.region}a", "${var.region}b", "${var.region}c"], 0, var.availability_zone_count)

  public_subnets = [for idx, az in local.azs : {
    id                = "subnet-pub-${substr(md5("${random_pet.vpc.id}-pub-${az}"), 0, 14)}"
    cidr              = cidrsubnet(var.cidr, 4, idx)
    availability_zone = az
    type              = "public"
  }]

  private_subnets = [for idx, az in local.azs : {
    id                = "subnet-prv-${substr(md5("${random_pet.vpc.id}-prv-${az}"), 0, 14)}"
    cidr              = cidrsubnet(var.cidr, 4, idx + var.availability_zone_count)
    availability_zone = az
    type              = "private"
  }]

  subnets = concat(local.public_subnets, local.private_subnets)
}
