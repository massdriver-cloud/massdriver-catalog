resource "massdriver_resource" "landing_zone" {
  field = "landing_zone"
  name  = "${var.team} landing zone"

  resource = jsonencode({
    team = var.team

    network = {
      vpc_id            = var.network.vpc_id
      region            = var.network.region
      cidr              = var.network_slice
      subnet_ids        = aws_subnet.team[*].id
      security_group_id = aws_security_group.team.id
    }

    registry = {
      name        = var.registry.name
      url         = var.registry.url
      arn         = var.registry.arn
      region      = var.registry.region
      registry_id = var.registry.registry_id
    }

    repository = {
      full_name      = var.repository.full_name
      url            = var.repository.url
      clone_url      = var.repository.clone_url
      default_branch = var.repository.default_branch
    }
  })
}
