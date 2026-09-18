locals {
  name_prefix = var.md_metadata.name_prefix

  # The bundle registers the range only when the operator turns it on and gives
  # an endpoint. Until then it records the range inside Massdriver alone.
  register = var.register_with_ipam && var.ipam_endpoint != ""
}

check "endpoint_present" {
  assert {
    condition     = !var.register_with_ipam || var.ipam_endpoint != ""
    error_message = "Registration is on, and the IPAM endpoint is empty. Give the endpoint, or turn registration off."
  }
}

# The management system receives the range, the pool, and the owner. Replace the
# body and the headers with the contract of your own system.
data "http" "register" {
  count = local.register ? 1 : 0

  url    = var.ipam_endpoint
  method = "POST"

  request_headers = {
    Content-Type = "application/json"
  }

  request_body = jsonencode({
    cidr        = var.cidr
    pool        = var.pool
    region      = var.region
    name        = local.name_prefix
    owner       = var.md_metadata.target.contact_email
    environment = var.md_metadata.default_tags["md-target"]
    project     = var.md_metadata.default_tags["md-project"]
  })

  lifecycle {
    postcondition {
      condition     = contains([200, 201, 409], self.status_code)
      error_message = "The IPAM system answered with ${self.status_code}. It accepts 200, 201, or 409."
    }
  }
}
