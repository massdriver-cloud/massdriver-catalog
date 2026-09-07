locals {
  full_name = var.md_metadata.name_prefix
  use_image = var.code_source == "registry"

  method = split(" ", var.route)[0]
  path   = split(" ", var.route)[1]

  # Both of these are optional connections. Absent, the function still runs —
  # it just runs on the public network and behind an open door.
  zone       = try(var.landing_zone, null)
  in_network = local.zone != null && var.attach_to_network

  authorizer_id   = try(var.authorizer.authorizer_id, null)
  allowed_domains = try(join(",", var.authorizer.allowed_domains), "")

  registry_url = try(var.landing_zone.registry.url, "")
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/aws/lambda/${local.full_name}"
  retention_in_days = var.log_retention_days

  # See .checkov.yaml for why this is not encrypted with a key of our own.
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

# Scoped to the one table that was connected. Connecting a different table
# changes what this function can reach; nothing else in the account is
# reachable, and nobody wrote a policy to make that true.
resource "aws_iam_role_policy" "table" {
  name = "use-table"
  role = aws_iam_role.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      Resource = [
        var.table.arn,
        "${var.table.arn}/index/*",
      ]
    }]
  })
}

# Attaching to the network means Lambda creates interfaces on the team's
# subnets, and only the service can be told which. The actions cannot be
# narrowed to a resource because the interfaces do not exist yet.
resource "aws_iam_role_policy_attachment" "vpc" {
  count = local.in_network ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "starter" {
  count = local.use_image ? 0 : 1

  type        = "zip"
  output_path = "${path.module}/starter.zip"

  source {
    filename = "index.py"
    content  = file("${path.module}/files/starter.py")
  }
}

resource "aws_lambda_function" "main" {
  function_name = local.full_name
  role          = aws_iam_role.main.arn
  memory_size   = var.memory_mb
  timeout       = var.timeout_seconds

  # A ceiling rather than a reservation of the whole pool: one runaway endpoint
  # cannot starve every other function in the account.
  reserved_concurrent_executions = var.max_concurrent_executions

  package_type = local.use_image ? "Image" : "Zip"
  image_uri    = local.use_image ? "${local.registry_url}:${var.image_tag}" : null

  filename         = local.use_image ? null : data.archive_file.starter[0].output_path
  source_code_hash = local.use_image ? null : data.archive_file.starter[0].output_base64sha256
  runtime          = local.use_image ? null : "python3.12"
  handler          = local.use_image ? null : "index.handler"

  dynamic "vpc_config" {
    for_each = local.in_network ? [1] : []
    content {
      subnet_ids         = var.landing_zone.network.subnet_ids
      security_group_ids = [var.landing_zone.network.security_group_id]
    }
  }

  environment {
    variables = merge(var.environment, {
      TABLE_NAME      = var.table.name
      PARTITION_KEY   = var.table.partition_key
      ALLOWED_DOMAINS = local.allowed_domains
    })
  }

  tracing_config {
    mode = "Active"
  }

  # Code signing, dead letter queues and environment encryption are all
  # deliberately absent. See .checkov.yaml.

  depends_on = [aws_cloudwatch_log_group.main]
}

resource "aws_apigatewayv2_integration" "main" {
  api_id                 = var.api.api_id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.main.invoke_arn
  payload_format_version = "2.0"
}

# The route is where a sign-in policy actually takes effect. Connecting an
# authorizer flips this from open to closed; disconnecting it opens it again.
resource "aws_apigatewayv2_route" "main" {
  api_id    = var.api.api_id
  route_key = "${local.method} ${local.path}"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"

  authorization_type = local.authorizer_id == null ? "NONE" : "JWT"
  authorizer_id      = local.authorizer_id
}

resource "aws_lambda_permission" "api" {
  statement_id  = "AllowInvokeFromApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api.execution_arn}/*/*"
}
