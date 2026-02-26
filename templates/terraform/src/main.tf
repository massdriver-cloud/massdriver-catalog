# Main infrastructure code
#
# Available variables from massdriver.yaml:
#   var.instance_name      - string
#   var.instance_count     - integer
#   var.enable_monitoring  - boolean
#   var.tags               - list(string)
#   var.advanced           - object({ timeout_seconds, retry_count })
#   var.md_metadata        - Massdriver metadata (name_prefix, default_tags, etc.)
#
# Connection variables (if configured):
#   var.<connection_name>  - artifact data from connected bundles

locals {
  name_prefix = var.md_metadata.name_prefix
}

# Example resource - replace with your infrastructure
resource "null_resource" "example" {
  triggers = {
    instance_name = var.instance_name
    name_prefix   = local.name_prefix
  }
}

# Output example - useful for debugging during development
output "instance_info" {
  value = {
    name       = var.instance_name
    count      = var.instance_count
    monitoring = var.enable_monitoring
  }
}
