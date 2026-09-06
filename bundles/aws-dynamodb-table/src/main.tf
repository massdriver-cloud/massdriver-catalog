locals {
  on_demand = var.capacity == "on_demand"

  # An unset optional param arrives as null, and try() only catches errors —
  # try(null, "") is still null, which renders the dynamic blocks below empty.
  has_sort = var.sort_key != null && var.sort_key != ""
  has_ttl  = var.ttl_attribute != null && var.ttl_attribute != ""

  # Prefixed with the deployment so two projects can both have an "items" table
  # without colliding — table names are account-wide, not project-scoped.
  full_name = "${var.md_metadata.name_prefix}-${var.table_name}"
}

resource "aws_dynamodb_table" "main" {
  name         = local.full_name
  billing_mode = local.on_demand ? "PAY_PER_REQUEST" : "PROVISIONED"
  hash_key     = var.partition_key
  range_key    = local.has_sort ? var.sort_key : null

  read_capacity  = local.on_demand ? null : var.read_capacity
  write_capacity = local.on_demand ? null : var.write_capacity

  deletion_protection_enabled = var.deletion_protection

  # Only the key attributes are declared. Everything else a record carries is
  # whatever the application decides to put there, which is the point of this
  # kind of table.
  attribute {
    name = var.partition_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = local.has_sort ? [1] : []
    content {
      name = var.sort_key
      type = "S"
    }
  }

  dynamic "ttl" {
    for_each = local.has_ttl ? [1] : []
    content {
      attribute_name = var.ttl_attribute
      enabled        = true
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  # Encrypted at rest with a key AWS owns. See .checkov.yaml for why this is not
  # a customer managed key.
  server_side_encryption {
    enabled = false
  }
}
