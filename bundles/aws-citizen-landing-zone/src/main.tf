locals {
  azs = var.network.availability_zones

  # One subnet per zone, carved out of the team's own slice. Two bits leaves
  # four, so a slice spans up to four zones.
  subnet_cidrs = [for i, az in local.azs : cidrsubnet(var.network_slice, 2, i)]

  gateways   = var.network.nat_gateway_ids
  has_egress = length(local.gateways) > 0
}

resource "aws_subnet" "team" {
  count = length(local.azs)

  vpc_id            = var.network.vpc_id
  cidr_block        = local.subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.team}-${local.azs[count.index]}"
    Team = var.team
  }
}

# The team gets its own route table per zone rather than sharing the network's.
# It means a team's routing can be changed — a proxy, a peering, a route to
# somewhere private — without touching a table every other team is also using.
resource "aws_route_table" "team" {
  count = length(local.azs)

  vpc_id = var.network.vpc_id
  tags = {
    Name = "${var.team}-${local.azs[count.index]}"
    Team = var.team
  }
}

# The gateways belong to the network, not the team. With one shared gateway
# every zone routes through it; with one per zone each routes through its own.
resource "aws_route" "team_egress" {
  count = local.has_egress ? length(local.azs) : 0

  route_table_id         = aws_route_table.team[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = local.gateways[count.index % length(local.gateways)]
}

resource "aws_route_table_association" "team" {
  count = length(local.azs)

  subnet_id      = aws_subnet.team[count.index].id
  route_table_id = aws_route_table.team[count.index].id
}

# One group per team. Members can reach each other, and everything they run can
# call out; nothing outside the team can open a connection in. An app that needs
# public traffic gets it through an API in front, never by opening this.
resource "aws_security_group" "team" {
  name        = "${var.team}-default"
  description = "Default access for everything ${var.team} runs"
  vpc_id      = var.network.vpc_id

  tags = { Name = "${var.team}-default" }
}

resource "aws_vpc_security_group_ingress_rule" "team_self" {
  security_group_id = aws_security_group.team.id
  description       = "Anything this team runs can reach anything else it runs"

  referenced_security_group_id = aws_security_group.team.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "team_out" {
  security_group_id = aws_security_group.team.id
  description       = "Outbound to anywhere"

  # checkov:skip=CKV_AWS_382: applications legitimately call third-party APIs and
  # package registries. Restricting egress here would mean maintaining an
  # allowlist per team, which is a policy decision for ops, not a bundle default.
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
