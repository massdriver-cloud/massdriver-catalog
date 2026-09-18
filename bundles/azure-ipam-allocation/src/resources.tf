locals {
  response       = local.register ? jsondecode(data.http.register[0].response_body) : {}
  remote_id      = try(local.response.id, "")
  allocation_ref = var.allocation_id != "" ? var.allocation_id : local.remote_id
}

resource "massdriver_resource" "allocation" {
  field = "allocation"
  name  = "Address Range ${var.cidr}"

  resource = jsonencode({
    cidr          = var.cidr
    pool          = var.pool
    region        = var.region
    allocation_id = local.allocation_ref
    registered    = local.register
  })
}
