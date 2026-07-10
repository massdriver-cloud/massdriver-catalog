resource "massdriver_resource" "registry" {
  field = "registry"
  name  = "AWS ECR ${var.repository_name}"

  resource = jsonencode({
    id              = aws_ecr_repository.main.arn
    registry_url    = split("/", aws_ecr_repository.main.repository_url)[0]
    repository_url  = aws_ecr_repository.main.repository_url
    repository_name = aws_ecr_repository.main.name
    region          = var.region
  })
}
