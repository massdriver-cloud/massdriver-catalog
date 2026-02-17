resource "massdriver_artifact" "domain" {
  field = "domain"
  name  = "SageMaker Domain ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    domain_id          = aws_sagemaker_domain.main.id
    domain_arn         = aws_sagemaker_domain.main.arn
    execution_role_arn = aws_iam_role.sagemaker_execution.arn
    default_bucket     = aws_s3_bucket.sagemaker.id
    studio_url         = aws_sagemaker_domain.main.url
    region             = var.vpc.region
    vpc_id             = var.vpc.id
    subnet_ids         = var.subnet_ids
    security_group_id  = aws_security_group.sagemaker.id
  })
}
