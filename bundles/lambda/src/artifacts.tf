resource "massdriver_artifact" "lambda_function" {
  field = "lambda_function"
  name  = "Lambda TODO API ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    name        = var.md_metadata.name_prefix
    service_url = aws_lambda_function_url.todo_api.function_url
    tags        = var.md_metadata.default_tags
  })
}
