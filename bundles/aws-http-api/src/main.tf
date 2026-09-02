locals {
  full_name = "${var.landing_zone.team}-${var.name}"
}

resource "aws_apigatewayv2_api" "main" {
  name          = local.full_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_origins
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${local.full_name}"
  retention_in_days = var.log_retention_days

  # checkov:skip=CKV_AWS_158: request metadata only. A customer managed key adds
  # a key to rotate without protecting anything that isn't already public.
}

# $default auto-deploys, so attaching a new function publishes it without a
# separate deployment step. That is what makes "add another Lambda" a one-click
# operation for a team rather than a release process.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.throttle_rate
    throttling_burst_limit = var.throttle_rate * 2
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }
}

# Until a function is attached there are no routes, and a caller would get a
# bare 404 with no explanation. This answers instead, so a team can see the
# address working the moment it exists.
resource "aws_apigatewayv2_route" "placeholder" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.placeholder.id}"
}

resource "aws_apigatewayv2_integration" "placeholder" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 404 })
  }
}
