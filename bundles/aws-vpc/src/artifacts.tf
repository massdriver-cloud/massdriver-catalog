resource "massdriver_artifact" "aws_vpc" {
  field = "aws_vpc"
  name  = "VPC ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id   = aws_vpc.main.id
    cidr = aws_vpc.main.cidr_block
    subnets = concat(
      [for s in aws_subnet.public : {
        id   = s.id
        cidr = s.cidr_block
        type = "public"
      }],
      [for s in aws_subnet.private : {
        id   = s.id
        cidr = s.cidr_block
        type = "private"
      }]
    )
  })
}
