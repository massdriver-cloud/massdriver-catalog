locals {
  # Private space above the zones actually in use. A landing zone takes its
  # slice from here, which is what lets teams be added without ops ever
  # touching this bundle again.
  free_private_blocks = [
    for i in range(var.availability_zone_count, 8) :
    cidrsubnet(local.private_prefix, 3, i)
  ]
}

resource "massdriver_resource" "network" {
  field = "network"
  name  = "VPC ${var.name} (${var.region})"

  resource = jsonencode({
    vpc_id             = aws_vpc.main.id
    region             = var.region
    cidr               = aws_vpc.main.cidr_block
    availability_zones = local.azs
    public_subnet_ids  = aws_subnet.public[*].id
    private_subnet_ids = aws_subnet.private[*].id
    unused_cidr_blocks = local.free_private_blocks
  })
}
