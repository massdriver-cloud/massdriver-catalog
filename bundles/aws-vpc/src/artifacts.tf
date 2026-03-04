resource "massdriver_artifact" "vpc" {
  field = "vpc"
  name  = "AWS VPC ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    id     = aws_vpc.main.id
    arn    = aws_vpc.main.arn
    cidr   = aws_vpc.main.cidr_block
    region = var.region
    public_subnets = [
      for subnet in aws_subnet.public : {
        id                = subnet.id
        arn               = subnet.arn
        cidr              = subnet.cidr_block
        availability_zone = subnet.availability_zone
      }
    ]
    private_subnets = [
      for subnet in aws_subnet.private : {
        id                = subnet.id
        arn               = subnet.arn
        cidr              = subnet.cidr_block
        availability_zone = subnet.availability_zone
      }
    ]
  })
}
