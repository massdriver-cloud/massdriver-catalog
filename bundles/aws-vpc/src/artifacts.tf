resource "massdriver_resource" "network" {
  field = "network"
  name  = "AWS VPC ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    vpc_id                    = aws_vpc.main.id
    cidr                      = var.cidr
    region                    = var.region
    default_security_group_id = aws_default_security_group.main.id
    subnets = concat(
      [for az, subnet in aws_subnet.public : {
        id                = subnet.id
        name              = "${var.md_metadata.name_prefix}-public-${az}"
        cidr              = subnet.cidr_block
        tier              = "public"
        availability_zone = az
      }],
      [for az, subnet in aws_subnet.private : {
        id                = subnet.id
        name              = "${var.md_metadata.name_prefix}-private-${az}"
        cidr              = subnet.cidr_block
        tier              = "private"
        availability_zone = az
      }]
    )
  })
}
