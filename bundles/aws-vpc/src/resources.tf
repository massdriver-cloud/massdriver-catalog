resource "massdriver_resource" "network" {
  field = "network"
  name  = "VPC ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id     = aws_vpc.main.id
    cidr   = aws_vpc.main.cidr_block
    region = var.region
    subnets = concat(
      [for s in aws_subnet.public : {
        id                = s.id
        cidr              = s.cidr_block
        type              = "public"
        availability_zone = s.availability_zone
      }],
      [for s in aws_subnet.private : {
        id                = s.id
        cidr              = s.cidr_block
        type              = "private"
        availability_zone = s.availability_zone
      }],
    )
  })
}
