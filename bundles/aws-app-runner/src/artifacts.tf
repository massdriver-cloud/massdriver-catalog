resource "massdriver_artifact" "service" {
  field = "service"
  name  = "App Runner ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    name          = aws_apprunner_service.main.service_name
    deployment_id = aws_apprunner_service.main.service_id
    service_url   = aws_apprunner_service.main.service_url
    tags          = var.md_metadata.default_tags
  })
}
