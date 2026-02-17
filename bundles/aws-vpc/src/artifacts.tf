resource "massdriver_artifact" "vpc" {
  field = "vpc"
  name  = "AWS VPC ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id                 = aws_vpc.main.id
    arn                = aws_vpc.main.arn
    cidr               = var.cidr
    region             = var.region
    subnets            = local.subnets
    s3_vpc_endpoint_id = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
  })
}
