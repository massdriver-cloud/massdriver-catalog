resource "massdriver_artifact" "service" {
  field = "service"
  name  = "App Runner ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    id  = aws_apprunner_service.main.id
    arn = aws_apprunner_service.main.arn
    url = "https://${aws_apprunner_service.main.service_url}"
  })
}
