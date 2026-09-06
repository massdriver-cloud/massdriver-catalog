# The gateway itself verifies the token's signature, issuer, audience and
# expiry before anything downstream is invoked. That is what turns an
# unauthenticated request away at the door rather than in application code.
#
# Which domains are allowed is a separate question: the `hd` claim is not
# something the gateway can be told to check, so it travels with this resource
# and the application enforces it on a request the gateway has already proven
# is genuine.
resource "aws_apigatewayv2_authorizer" "main" {
  api_id           = var.api.api_id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.md_metadata.name_prefix}-google"

  jwt_configuration {
    issuer   = "https://accounts.google.com"
    audience = [var.google_client_id]
  }
}
