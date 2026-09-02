resource "massdriver_resource" "network" {
  field = "network"
  name  = "VPC ${var.name} (${var.region})"

  resource = jsonencode({
    vpc_id             = aws_vpc.main.id
    region             = var.region
    cidr               = aws_vpc.main.cidr_block
    availability_zones = local.azs
    public_subnet_ids  = aws_subnet.public[*].id
    nat_gateway_ids    = aws_nat_gateway.main[*].id

    # Candidates, not a ledger. Nothing here is reserved until a team is given
    # one, and two teams handed the same range will collide at apply time.
    available_cidr_blocks = local.team_blocks
  })
}
