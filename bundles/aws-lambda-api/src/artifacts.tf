resource "massdriver_resource" "app" {
  field = "app"
  name  = "TODO API ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id          = aws_lambda_function.main.arn
    url         = aws_lambda_function_url.main.function_url
    health_path = "/todos"
  })
}
