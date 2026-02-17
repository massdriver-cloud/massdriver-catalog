resource "massdriver_artifact" "application" {
  field = "application"
  name  = "Lambda API ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    deployment_id = var.md_metadata.deployment.id
    name          = var.api_name
    url           = aws_apigatewayv2_stage.api.invoke_url
    tags          = var.md_metadata.default_tags
  })
}
