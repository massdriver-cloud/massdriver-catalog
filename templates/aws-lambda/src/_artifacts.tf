# Use massdriver_resource to emit resources for other bundles (and people) to
# consume. The payload must match the resource type's schema.
#
# Recommended for APIs — emit an `application` resource (uncomment the matching
# block under `artifacts:` in massdriver.yaml too):
#
# resource "massdriver_resource" "app" {
#   field = "app"
#   name  = "API ${var.md_metadata.name_prefix}"
#
#   resource = jsonencode({
#     id          = aws_lambda_function.main.arn
#     url         = aws_lambda_function_url.main.function_url
#     health_path = "/"
#   })
# }
