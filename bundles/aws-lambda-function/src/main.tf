locals {
  full_name = "${var.landing_zone.team}-${var.name}"
  use_image = var.code_source == "registry"

  method = split(" ", var.route)[0]
  path   = split(" ", var.route)[1]
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/lambda/${local.full_name}"
  retention_in_days = 30

  # checkov:skip=CKV_AWS_158: what an application chooses to log is the team's
  # call, and a per-function key would be a key per endpoint to rotate.
}

resource "aws_iam_role" "main" {
  name = "${local.full_name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "logs" {
  name = "write-logs"
  role = aws_iam_role.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.main.arn}:*"
    }]
  })
}

# Attaching to the network means Lambda creates network interfaces on the
# team's subnets, and only the service itself can be told which. The actions
# cannot be narrowed to a resource because the interfaces do not exist yet.
resource "aws_iam_role_policy_attachment" "vpc" {
  count = var.attach_to_network ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# The example runs before the team has built anything, so the endpoint is live
# and provably reachable on day one rather than after their first green build.
data "archive_file" "starter" {
  count = local.use_image ? 0 : 1

  type        = "zip"
  output_path = "${path.module}/starter.zip"

  source {
    filename = "index.py"
    content  = <<-PY
      import json, os

      def handler(event, context):
          return {
              "statusCode": 200,
              "headers": {"content-type": "application/json"},
              "body": json.dumps({
                  "message": "Hello from ${local.full_name}",
                  "team": os.environ.get("TEAM", "unknown"),
                  "path": event.get("rawPath", "/"),
              }),
          }
    PY
  }
}

resource "aws_lambda_function" "main" {
  function_name = local.full_name
  role          = aws_iam_role.main.arn
  memory_size   = var.memory_mb
  timeout       = var.timeout_seconds

  package_type = local.use_image ? "Image" : "Zip"
  image_uri    = local.use_image ? "${var.landing_zone.registry.url}:${var.image_tag}" : null

  filename         = local.use_image ? null : data.archive_file.starter[0].output_path
  source_code_hash = local.use_image ? null : data.archive_file.starter[0].output_base64sha256
  runtime          = local.use_image ? null : "python3.12"
  handler          = local.use_image ? null : "index.handler"

  dynamic "vpc_config" {
    for_each = var.attach_to_network ? [1] : []
    content {
      subnet_ids         = var.landing_zone.network.subnet_ids
      security_group_ids = [var.landing_zone.network.security_group_id]
    }
  }

  environment {
    variables = merge(var.environment, {
      TEAM = var.landing_zone.team
    })
  }

  tracing_config {
    mode = "Active"
  }

  # checkov:skip=CKV_AWS_272: signing requires a signing profile the team does not
  # have. The image digest and the repository's own scan are what stand in here.
  # checkov:skip=CKV_AWS_116: a dead letter queue only helps async invocations,
  # and everything behind an API is synchronous — the caller sees the error.
  # checkov:skip=CKV_AWS_173: environment holds settings, not secrets; the schema
  # says so, and anything sensitive belongs in a secret store instead.

  depends_on = [aws_cloudwatch_log_group.main]
}

resource "aws_apigatewayv2_integration" "main" {
  api_id                 = var.api.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.main.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "main" {
  api_id    = var.api.api_id
  route_key = "${local.method} ${local.path}"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

# Scoped to this API's execution ARN, so no other API — in this account or any
# other — can invoke the function.
resource "aws_lambda_permission" "api" {
  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api.execution_arn}/*/*"
}
