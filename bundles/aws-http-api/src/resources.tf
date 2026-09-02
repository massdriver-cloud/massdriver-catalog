resource "massdriver_resource" "api" {
  field = "api"
  name  = "API ${local.full_name}"

  resource = jsonencode({
    url           = aws_apigatewayv2_stage.default.invoke_url
    api_id        = aws_apigatewayv2_api.main.id
    region        = var.landing_zone.network.region
    execution_arn = aws_apigatewayv2_api.main.execution_arn
    stage         = aws_apigatewayv2_stage.default.name
  })
}
