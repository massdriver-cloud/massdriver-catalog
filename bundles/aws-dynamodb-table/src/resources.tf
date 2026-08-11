resource "massdriver_resource" "table" {
  field = "table"
  name  = "Table ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    name          = aws_dynamodb_table.main.name
    arn           = aws_dynamodb_table.main.arn
    region        = var.region
    partition_key = var.partition_key
    sort_key      = var.sort_key
    policies = [
      {
        id   = aws_iam_policy.read.arn
        name = "read"
      },
      {
        id   = aws_iam_policy.write.arn
        name = "write"
      },
      {
        id   = aws_iam_policy.admin.arn
        name = "admin"
      },
    ]
  })
}
