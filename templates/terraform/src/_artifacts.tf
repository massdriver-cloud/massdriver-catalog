# Use massdriver_artifact resources to emit artifacts for other bundles to consume.
# The artifact data must match your artifact definition schema.
#
# resource "massdriver_artifact" "my_artifact" {
#   field                = "my_artifact"
#   provider_resource_id = aws_instance.main.arn  # or other unique resource ID
#   name                 = "My Artifact (${var.md_metadata.name_prefix})"
#   artifact = jsonencode({
#     data = {
#       # Fields matching your artifact definition schema
#       endpoint = aws_instance.main.public_ip
#       port     = 443
#     }
#     specs = {
#       # Optional specs for policy/compliance
#     }
#   })
# }
