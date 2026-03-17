resource "massdriver_artifact" "table" {
  field = "table"
  name  = "DynamoDB ${var.table_name} (${var.md_metadata.name_prefix})"
  artifact = jsonencode({
    arn        = aws_dynamodb_table.main.arn
    name       = aws_dynamodb_table.main.name
    region     = var.region
    stream_arn = aws_dynamodb_table.main.stream_arn != null ? aws_dynamodb_table.main.stream_arn : ""
    policies = [
      {
        id   = aws_iam_policy.read_only.arn
        name = "Read Only"
      },
      {
        id   = aws_iam_policy.read_write.arn
        name = "Read / Write"
      },
    ]
  })
}
