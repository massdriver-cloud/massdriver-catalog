# Use massdriver_resource resources to emit resources for other bundles to consume.
# The resource data must match your resource type schema.
#
# resource "massdriver_resource" "my_resource" {
#   field = "my_resource"
#   name  = "My Resource (${var.md_metadata.name_prefix})"
#   resource = jsonencode({
#     # Fields matching your resource type schema
#     endpoint = aws_instance.main.public_ip
#     port     = 443
#   })
# }
