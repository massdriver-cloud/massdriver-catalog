resource "massdriver_resource" "authorizer" {
  field = "authorizer"
  name  = "Google sign-in (${join(", ", var.allowed_domains)})"

  resource = jsonencode({
    authorizer_id   = aws_apigatewayv2_authorizer.main.id
    api_id          = var.api.api_id
    region          = var.api.region
    provider        = "Google Workspace"
    allowed_domains = var.allowed_domains
  })
}
