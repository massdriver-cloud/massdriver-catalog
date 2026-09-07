resource "massdriver_resource" "registry" {
  field = "registry"
  name  = "ECR ${aws_ecr_repository.main.name}"

  resource = jsonencode({
    name = aws_ecr_repository.main.name
    # repository_url has no tag on it, so consumers append their own.
    url         = aws_ecr_repository.main.repository_url
    arn         = aws_ecr_repository.main.arn
    region      = var.region
    registry_id = data.aws_caller_identity.current.account_id
  })
}
