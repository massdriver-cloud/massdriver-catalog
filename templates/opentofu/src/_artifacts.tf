# Use massdriver_resource to emit resources for other bundles to consume.
# (massdriver_resource replaces the deprecated massdriver_artifact.)
# The payload must match your resource type's schema.
#
# resource "massdriver_resource" "my_resource" {
#   field = "my_resource"
#   name  = "My Resource (${var.md_metadata.name_prefix})"
#   resource = jsonencode({
#     # Fields matching your resource type's schema
#     endpoint = aws_instance.main.public_ip
#     port     = 443
#   })
# }
