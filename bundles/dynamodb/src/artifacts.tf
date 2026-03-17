resource "massdriver_artifact" "table" {
  field = "table"
  name  = "DynamoDB Table ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    arn        = aws_dynamodb_table.main.arn
    name       = aws_dynamodb_table.main.name
    region     = var.region
    stream_arn = aws_dynamodb_table.main.stream_arn
    policies = [
      {
        id   = "read-only"
        name = "Read"
      },
      {
        id   = "read-write"
        name = "Write"
      },
      {
        id   = "admin"
        name = "Admin"
      }
    ]
  })
}
