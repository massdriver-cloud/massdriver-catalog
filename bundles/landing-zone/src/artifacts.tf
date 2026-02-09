resource "massdriver_artifact" "zone" {
  field = "zone"
  name  = "Zone ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id         = local.project_id
    network_id         = local.network_id
    service_account_id = local.service_account_id
  })
}
