locals {
  azs = var.network.availability_zones

  # One subnet per zone, carved out of the team's slice. Three bits leaves
  # eight, so a slice can span up to eight zones without re-planning.
  subnet_cidrs = [for i, az in local.azs : cidrsubnet(var.network_slice, 3, i)]
}

# The platform's own private subnets are tagged by zone, and each already routes
# out through whichever NAT the network was built with. Finding them by tag is
# what lets a team's subnets inherit egress without this bundle knowing or
# caring how the network chose to provide it.
data "aws_route_table" "private" {
  for_each = toset(local.azs)

  vpc_id = var.network.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*-private-${each.value}"]
  }
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

resource "aws_route_table_association" "team" {
  count = length(local.azs)

  subnet_id      = aws_subnet.team[count.index].id
  route_table_id = data.aws_route_table.private[local.azs[count.index]].id
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
