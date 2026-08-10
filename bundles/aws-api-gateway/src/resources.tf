resource "massdriver_resource" "api" {
  field = "api"
  name  = "API ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id            = aws_apigatewayv2_api.main.id
    endpoint      = aws_apigatewayv2_stage.main.invoke_url
    execution_arn = aws_apigatewayv2_api.main.execution_arn
    stage         = aws_apigatewayv2_stage.main.name
    region        = var.region
  })
}
