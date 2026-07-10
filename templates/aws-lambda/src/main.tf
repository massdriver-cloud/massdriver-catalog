# A Lambda function with a public function URL, fed by the code in ./function.
# Replace ./function/index.mjs with your application code.

locals {
  function_name = var.md_metadata.name_prefix
}

data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/.archive/function.zip"
}

resource "aws_cloudwatch_log_group" "function" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
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

resource "aws_iam_role" "function" {
  name               = local.function_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.function.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "main" {
  function_name    = local.function_name
  role             = aws_iam_role.function.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  memory_size      = var.memory_mb
  timeout          = var.timeout_seconds
  filename         = data.archive_file.function.output_path
  source_code_hash = data.archive_file.function.output_base64sha256

  # environment {
  #   variables = {
  #     EXAMPLE = "value"
  #   }
  # }

  depends_on = [aws_cloudwatch_log_group.function]
}

# Public by default so the scaffold works immediately. For real use, switch
# authorization_type to "AWS_IAM" or front the function with an API gateway.
resource "aws_lambda_function_url" "main" {
  function_name      = aws_lambda_function.main.function_name
  authorization_type = "NONE"
}
