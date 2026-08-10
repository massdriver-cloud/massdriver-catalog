data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4

  keepers = {
    name = var.md_metadata.name_prefix
  }
}

locals {
  function_name = substr(var.md_metadata.name_prefix, 0, 64)
  stem          = substr(var.md_metadata.name_prefix, 0, 24)
  code_bucket   = substr("${var.md_metadata.name_prefix}-code-${random_id.suffix.hex}", 0, 63)

  # Linking a virtual network attaches the function to it. Left unlinked, the
  # function runs on the Lambda-managed network, which is faster to start and is
  # the right default unless the function must reach something private.
  has_network = try(var.network.id, null) != null

  private_subnet_ids = local.has_network ? [
    for s in var.network.subnets : s.id if try(s.type, "private") == "private"
  ] : []

  # Linking a gateway gives the function a public route. Left unlinked, the
  # function is only reachable by whatever else is allowed to invoke it.
  has_gateway = try(var.gateway.id, null) != null

  is_python          = startswith(var.runtime, "python")
  bootstrap_filename = local.is_python ? "index.py" : "index.js"

  bootstrap_python = <<-PY
    import json


    def handler(event, context):
        return {
            "statusCode": 200,
            "headers": {"content-type": "application/json"},
            "body": json.dumps(
                {
                    "message": "Placeholder function. Upload your code and set Code Object Key.",
                    "function": "${local.function_name}",
                }
            ),
        }
  PY

  bootstrap_node = <<-JS
    exports.handler = async () => ({
      statusCode: 200,
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        message: "Placeholder function. Upload your code and set Code Object Key.",
        function: "${local.function_name}",
      }),
    });
  JS

  bootstrap_content = local.is_python ? local.bootstrap_python : local.bootstrap_node
}

################################################################################
# Encryption key
################################################################################

resource "aws_kms_key" "main" {
  description             = "Encrypts code, logs, and environment variables for ${local.function_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
      {
        # S3 access logs are written by the log-delivery service, which is not an
        # IAM principal in this account and needs its own grant.
        Sid       = "AllowS3LogDelivery"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
    ]
  })
}

resource "aws_kms_alias" "main" {
  name_prefix   = "alias/${local.stem}-fn-"
  target_key_id = aws_kms_key.main.key_id
}

################################################################################
# Code bucket
#
# The function reads its zip from here. Deploying new code is a sync into this
# bucket followed by a redeploy pointing at the new object key, so releases are
# traceable to an exact artifact.
################################################################################

resource "aws_s3_bucket" "code" {
  bucket = local.code_bucket

  tags = {
    Name = local.code_bucket
  }
}

resource "aws_s3_bucket_public_access_block" "code" {
  bucket = aws_s3_bucket.code.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "code" {
  bucket = aws_s3_bucket.code.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "code" {
  bucket = aws_s3_bucket.code.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "code" {
  bucket = aws_s3_bucket.code.id

  versioning_configuration {
    status = "Enabled"
  }
}

# The code bucket is its own access-log destination. Sending the logs to a
# separate bucket would just move the same question one hop further out.
resource "aws_s3_bucket_logging" "code" {
  bucket = aws_s3_bucket.code.id

  target_bucket = aws_s3_bucket.code.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "code" {
  bucket = aws_s3_bucket.code.id

  rule {
    id     = "housekeeping"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.code]
}

resource "aws_s3_bucket_policy" "code" {
  bucket = aws_s3_bucket.code.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.code.arn,
          "${aws_s3_bucket.code.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.code]
}

# A working placeholder so the function deploys before any real code exists.
# Replace it by uploading a zip and pointing Code Object Key at it.
data "archive_file" "bootstrap" {
  type        = "zip"
  output_path = "${path.module}/bootstrap.zip"

  source {
    filename = local.bootstrap_filename
    content  = local.bootstrap_content
  }
}

resource "aws_s3_object" "bootstrap" {
  bucket = aws_s3_bucket.code.id
  key    = "bootstrap.zip"
  source = data.archive_file.bootstrap.output_path
  # KMS-encrypted objects have no plain-MD5 etag, so change detection uses
  # source_hash instead.
  source_hash = data.archive_file.bootstrap.output_md5
  kms_key_id  = aws_kms_key.main.arn

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.code]
}

################################################################################
# Execution role
################################################################################

resource "aws_iam_role" "lambda" {
  name_prefix = substr("${local.stem}-fn-", 0, 32)

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy" "runtime" {
  name_prefix = "runtime-"
  role        = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "WriteLogs"
          Effect   = "Allow"
          Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
        },
        {
          Sid      = "ReadCode"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:GetObjectVersion"]
          Resource = "${aws_s3_bucket.code.arn}/*"
        },
        {
          Sid      = "UseKey"
          Effect   = "Allow"
          Action   = ["kms:Decrypt", "kms:DescribeKey"]
          Resource = aws_kms_key.main.arn
        },
      ],
      var.enable_dead_letter_queue ? [
        {
          Sid      = "SendToDeadLetterQueue"
          Effect   = "Allow"
          Action   = "sqs:SendMessage"
          Resource = aws_sqs_queue.dlq[0].arn
        },
      ] : [],
      var.tracing_enabled ? [
        {
          Sid      = "WriteTraces"
          Effect   = "Allow"
          Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
          Resource = "*"
        },
      ] : [],
    )
  })
}

# Managing network interfaces is required for a function attached to a network,
# and meaningless for one that is not.
resource "aws_iam_role_policy_attachment" "vpc_access" {
  count = local.has_network ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

################################################################################
# Logs, dead letters, networking
################################################################################

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.main.arn
}

resource "aws_sqs_queue" "dlq" {
  count = var.enable_dead_letter_queue ? 1 : 0

  name                      = "${local.function_name}-dlq"
  kms_master_key_id         = aws_kms_key.main.arn
  message_retention_seconds = 1209600

  tags = {
    Name = "${local.function_name}-dlq"
  }
}

resource "aws_security_group" "lambda" {
  count = local.has_network ? 1 : 0

  name_prefix = "${local.stem}-fn-"
  description = "Outbound access for ${local.function_name}"
  vpc_id      = var.network.id

  tags = {
    Name = local.function_name
  }
}

# A function needs to reach AWS service endpoints and whatever else it calls;
# the destinations are not knowable from inside this bundle.
resource "aws_vpc_security_group_egress_rule" "lambda_all" {
  count = local.has_network ? 1 : 0

  security_group_id = aws_security_group.lambda[0].id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

################################################################################
# Function
################################################################################

resource "aws_lambda_function" "main" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  handler       = var.handler
  runtime       = var.runtime
  memory_size   = var.memory_mb
  timeout       = var.timeout_seconds
  publish       = true

  s3_bucket = aws_s3_bucket.code.id
  s3_key    = var.code_key

  kms_key_arn                    = aws_kms_key.main.arn
  reserved_concurrent_executions = var.reserved_concurrency

  environment {
    variables = local.environment_variables
  }

  tracing_config {
    mode = var.tracing_enabled ? "Active" : "PassThrough"
  }

  dynamic "vpc_config" {
    for_each = local.has_network ? [1] : []

    content {
      subnet_ids         = local.private_subnet_ids
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_dead_letter_queue ? [1] : []

    content {
      target_arn = aws_sqs_queue.dlq[0].arn
    }
  }

  depends_on = [
    aws_s3_object.bootstrap,
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.runtime,
  ]
}

################################################################################
# Gateway routing
#
# Linking a gateway attaches this function to it. The function owns its own
# route, so several functions can share one gateway without any of them owning
# the gateway itself.
################################################################################

resource "aws_apigatewayv2_integration" "gateway" {
  count = local.has_gateway ? 1 : 0

  api_id                 = var.gateway.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.main.invoke_arn
  payload_format_version = "2.0"

  # API Gateway caps integrations at 30s regardless of the function's timeout.
  timeout_milliseconds = min(var.timeout_seconds * 1000, 30000)
}

resource "aws_apigatewayv2_route" "gateway" {
  count = local.has_gateway ? 1 : 0

  api_id    = var.gateway.id
  route_key = var.route_key
  target    = "integrations/${aws_apigatewayv2_integration.gateway[0].id}"
}

# Without this the gateway gets a 500 on every request - the function refuses
# invocations from a principal it has not been told to trust.
resource "aws_lambda_permission" "gateway" {
  count = local.has_gateway ? 1 : 0

  statement_id  = "AllowInvokeFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.gateway.execution_arn}/*/*"
}
