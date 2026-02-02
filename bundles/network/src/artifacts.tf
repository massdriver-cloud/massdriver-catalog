resource "massdriver_artifact" "network" {
  field = "network"
  name  = "Demo Network ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id      = random_pet.main.id
    cidr    = var.cidr
    subnets = local.subnets
  })
}
