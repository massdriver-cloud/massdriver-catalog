resource "massdriver_artifact" "vpc" {
  field = "vpc"
  name  = "AWS VPC ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id         = local.vpc_id
    arn        = "arn:aws:ec2:${local.region}:${local.account_id}:vpc/${local.vpc_id}"
    cidr       = var.cidr
    region     = local.region
    account_id = local.account_id
    subnets    = local.subnets
    security_group_ids = {
      default   = "sg-${substr(md5("${random_pet.vpc.id}-default"), 0, 17)}"
      endpoints = "sg-${substr(md5("${random_pet.vpc.id}-endpoints"), 0, 17)}"
    }
  })
}
