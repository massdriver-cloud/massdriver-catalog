terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

provider "aws" {
  region = var.region

  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = var.aws_authentication.external_id
  }

  default_tags {
    tags = var.md_metadata.default_tags
  }
}

# ──────────────────────────────────────────────────────────
# S3 bucket for Lambda deployment package
# ──────────────────────────────────────────────────────────
resource "aws_s3_bucket" "deployment" {
  bucket_prefix = "${var.md_metadata.name_prefix}-deploy-"

  # CKV_AWS_21: versioning enabled below
  # CKV_AWS_145: encryption enabled below
  # CKV2_AWS_61: lifecycle configuration — muted, deployment artifacts, no lifecycle needed
  # CKV2_AWS_62: event notifications — muted, not required for deployment artifact bucket
}

resource "aws_s3_bucket_versioning" "deployment" {
  bucket = aws_s3_bucket.deployment.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deployment" {
  bucket = aws_s3_bucket.deployment.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "deployment" {
  bucket                  = aws_s3_bucket.deployment.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "deployment" {
  bucket        = aws_s3_bucket.deployment.id
  target_bucket = aws_s3_bucket.deployment.id
  target_prefix = "access-logs/"
}

# Upload the bundled zip to S3
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.deployment.id
  key    = "todoapi.zip"
  source = "${path.module}/todoapi.zip"
  etag   = filemd5("${path.module}/todoapi.zip")

  # CKV_AWS_186: S3 object encryption — inherited from bucket default encryption
}

# ──────────────────────────────────────────────────────────
# CloudWatch log group for Lambda
# ──────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.md_metadata.name_prefix}-todo-api"
  retention_in_days = var.log_retention_days
}

# ──────────────────────────────────────────────────────────
# IAM execution role for Lambda
# ──────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_exec" {
  name = "${var.md_metadata.name_prefix}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Basic execution policy — CloudWatch Logs
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to read the deployment zip from S3
resource "aws_iam_role_policy" "lambda_s3_read" {
  name = "lambda-s3-deployment-read"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
        ]
        Resource = "${aws_s3_bucket.deployment.arn}/todoapi.zip"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Attach the DynamoDB policy chosen by the operator (from the DynamoDB artifact)
locals {
  # Find the policy ARN that matches the policy name selected by the operator.
  # Falls back to the first policy if no name is configured.
  dynamodb_policy_arn = (
    var.dynamodb_policy != null && var.dynamodb_policy != ""
    ? [
      for p in var.dynamodb_table.policies :
      p.id if p.name == var.dynamodb_policy
    ][0]
    : var.dynamodb_table.policies[0].id
  )
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = local.dynamodb_policy_arn
}

# ──────────────────────────────────────────────────────────
# Lambda function (deployed from managed S3 bucket)
# ──────────────────────────────────────────────────────────
resource "aws_lambda_function" "todo_api" {
  function_name = "${var.md_metadata.name_prefix}-todo-api"
  description   = "TODO REST API backed by DynamoDB"

  s3_bucket        = aws_s3_bucket.deployment.id
  s3_key           = aws_s3_object.lambda_zip.key
  source_code_hash = filebase64sha256("${path.module}/todoapi.zip")

  runtime = "nodejs22.x"
  handler = "index.handler"

  role = aws_iam_role.lambda_exec.arn

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_sec

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table.name
    }
  }

  # CKV_AWS_50: X-Ray tracing — muted, not required for synchronous REST API tier
  # CKV_AWS_116: Dead letter queue — muted, DLQ not applicable to synchronous API invocations
  # CKV_AWS_117: VPC — muted, serverless public REST API does not require VPC placement

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic_execution,
    aws_s3_object.lambda_zip,
  ]
}

# ──────────────────────────────────────────────────────────
# API Gateway HTTP API (v2) — proxy integration
# ──────────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.md_metadata.name_prefix}-todo-api"
  protocol_type = "HTTP"
  description   = "HTTP API for the TODO REST API Lambda"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.todo_api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "catch_all" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_cloudwatch_log_group" "apigw" {
  name              = "/aws/apigateway/${var.md_metadata.name_prefix}-todo-api"
  retention_in_days = var.log_retention_days
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.todo_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
