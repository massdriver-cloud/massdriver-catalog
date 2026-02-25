resource "massdriver_artifact" "table" {
  field = "table"
  name  = "DynamoDB Table ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    data = {
      infrastructure = {
        arn        = aws_dynamodb_table.main.arn
        table_name = aws_dynamodb_table.main.name
      }
      security = {
        iam = {
          read = {
            policy_arn = aws_iam_policy.read.arn
          }
          write = {
            policy_arn = aws_iam_policy.write.arn
          }
        }
      }
    }
    specs = {
      aws = {
        region = var.region
      }
    }
  })
}

resource "massdriver_artifact" "stream" {
  count = try(var.stream.enabled, false) ? 1 : 0
  field = "stream"
  name  = "DynamoDB Stream ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    data = {
      infrastructure = {
        arn       = aws_dynamodb_table.main.stream_arn
        table_arn = aws_dynamodb_table.main.arn
      }
      security = {
        iam = {
          read = {
            policy_arn = aws_iam_policy.stream[0].arn
          }
        }
      }
    }
    specs = {
      aws = {
        region = var.region
      }
    }
  })
}
