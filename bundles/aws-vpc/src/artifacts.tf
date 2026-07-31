resource "massdriver_resource" "network" {
  field = "network"
  name  = "AWS Network (${var.md_metadata.name_prefix})"
  resource = jsonencode({
    vpc_id = aws_vpc.main.id
    region = var.region
    cidr   = var.cidr
    subnets = concat(
      [for s in aws_subnet.public : {
        id                = s.id
        cidr              = s.cidr_block
        type              = "public"
        availability_zone = s.availability_zone
      }],
      [for s in aws_subnet.private : {
        id                = s.id
        cidr              = s.cidr_block
        type              = "private"
        availability_zone = s.availability_zone
      }]
    )
    nat_gateway_id       = aws_nat_gateway.main.id
    s3_vpc_endpoint_id   = aws_vpc_endpoint.s3.id
    ecr_vpc_endpoint_ids = [aws_vpc_endpoint.ecr_api.id, aws_vpc_endpoint.ecr_dkr.id]
  })
}
