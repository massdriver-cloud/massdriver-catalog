resource "massdriver_artifact" "api" {
  field = "api"
  name  = "TODO API (${var.md_metadata.name_prefix})"
  artifact = jsonencode({
    name           = aws_lambda_function.todo_api.function_name
    deployment_id  = var.md_metadata.deployment.id
    service_url    = aws_apigatewayv2_stage.default.invoke_url
    tags           = var.md_metadata.default_tags
  })
}
