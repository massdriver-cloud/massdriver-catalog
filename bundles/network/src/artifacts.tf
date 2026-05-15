resource "massdriver_resource" "network" {
  field = "network"
  name  = "Demo Network ${var.md_metadata.name_prefix}"
  resource = jsonencode({
    id      = random_pet.main.id
    cidr    = var.cidr
    region  = "us-east-1"
    subnets = local.subnets
  })
}
