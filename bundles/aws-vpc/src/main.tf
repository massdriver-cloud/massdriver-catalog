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

resource "random_pet" "vpc" {
  length = 2
  keepers = {
    cidr = var.cidr
    azs  = tostring(var.availability_zone_count)
  }
}

locals {
  region     = "us-east-1"
  account_id = "123456789012"
  vpc_id     = "vpc-${substr(md5(random_pet.vpc.id), 0, 17)}"

  azs = slice(["${local.region}a", "${local.region}b", "${local.region}c"], 0, var.availability_zone_count)

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
