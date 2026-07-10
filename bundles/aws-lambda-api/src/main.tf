terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.4"
    }
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

# Zip the handler at plan time. The .archive/ output dir sits outside
# function/ so the zip never ends up inside its own source tree.
data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/.archive/function.zip"
}

# The table shares this bundle's lifecycle on purpose: decommission the
# instance and the table (and its data) go with it. That's the point of a
# self-contained demo API — nothing left behind to clean up.
resource "aws_dynamodb_table" "todos" {
  name         = var.md_metadata.name_prefix
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Scoped to exactly this table — the function can't touch anything else.
data "aws_iam_policy_document" "table_access" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
    ]
    resources = [aws_dynamodb_table.todos.arn]
  }
}

resource "aws_iam_role" "function" {
  name               = var.md_metadata.name_prefix
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "table_access" {
  name   = "todos-table"
  role   = aws_iam_role.function.id
  policy = data.aws_iam_policy_document.table_access.json
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Declared before the function so the retention policy applies from the very
# first invoke — otherwise Lambda auto-creates the group with no expiry.
resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${var.md_metadata.name_prefix}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "main" {
  function_name = var.md_metadata.name_prefix
  role          = aws_iam_role.function.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  memory_size   = var.memory_mb
  timeout       = var.timeout_seconds

  filename         = data.archive_file.function.output_path
  source_code_hash = data.archive_file.function.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todos.name
    }
  }

  depends_on = [aws_cloudwatch_log_group.function]
}

# authorization_type = "NONE" makes this URL public on purpose — it's a demo
# API anyone can curl. For real workloads use "AWS_IAM" or put an API gateway
# with an authorizer in front.
resource "aws_lambda_function_url" "main" {
  function_name      = aws_lambda_function.main.function_name
  authorization_type = "NONE"
}
