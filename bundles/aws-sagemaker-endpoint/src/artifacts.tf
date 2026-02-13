resource "massdriver_artifact" "endpoint" {
  field = "endpoint"
  name  = "SageMaker Endpoint ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    endpoint_name = aws_sagemaker_endpoint.main.name
    endpoint_arn  = aws_sagemaker_endpoint.main.arn
    model_name    = aws_sagemaker_model.main.name
    region        = var.sagemaker_domain.region
  })
}
