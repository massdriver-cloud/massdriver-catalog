resource "massdriver_artifact" "vpc" {
  field                = "vpc"
  provider_resource_id = aws_vpc.main.arn
  name                 = "AWS VPC ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id     = aws_vpc.main.id
    vpc_id = aws_vpc.main.id
    region = var.region
    cidr   = var.cidr
    public_subnets = [
      for subnet in aws_subnet.public : {
        subnet_id         = subnet.id
        availability_zone = subnet.availability_zone
        cidr              = subnet.cidr_block
      }
    ]
    private_subnets = [
      for subnet in aws_subnet.private : {
        subnet_id         = subnet.id
        availability_zone = subnet.availability_zone
        cidr              = subnet.cidr_block
      }
    ]
  })
}
