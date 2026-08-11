resource "massdriver_resource" "function" {
  field = "function"
  name  = "Function ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    arn           = aws_lambda_function.main.arn
    invoke_arn    = aws_lambda_function.main.invoke_arn
    function_name = aws_lambda_function.main.function_name
    region        = var.region
    role_arn      = aws_iam_role.lambda.arn
    runtime       = var.runtime
    code_bucket   = aws_s3_bucket.code.bucket
    code_key      = var.code_key
  })
}
