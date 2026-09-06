locals {
  has_stream = try(aws_dynamodb_table.main.stream_arn, "") != ""

  # An optional field has to be left out, not set to null — the schema declares
  # these as strings, and a null is a type mismatch rather than an absence.
  optional_fields = merge(
    local.has_sort ? { sort_key = var.sort_key } : {},
    local.has_stream ? { stream_arn = aws_dynamodb_table.main.stream_arn } : {},
  )
}

resource "massdriver_resource" "table" {
  field = "table"
  name  = "Table ${var.table_name}"

  resource = jsonencode(merge({
    name          = aws_dynamodb_table.main.name
    arn           = aws_dynamodb_table.main.arn
    region        = var.region
    partition_key = var.partition_key
  }, local.optional_fields))
}
