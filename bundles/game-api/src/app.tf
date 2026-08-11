# Application wiring: what the game API knows about the resources linked to it.

locals {
  has_table = try(var.table.name, null) != null

  # The table publishes real IAM policies. The form shows their friendly names
  # ("read", "write", "admin"); this maps the chosen name back to the ARN so the
  # execution role can attach it.
  table_policy_arn = local.has_table && var.table_access != null ? one([
    for p in var.table.policies : p.id if p.name == var.table_access
  ]) : null

  environment_variables = merge(
    {
      LOG_LEVEL    = var.log_level
      APP_ENV      = var.md_metadata.default_tags["md-target"]
      STARTING_HP  = tostring(var.starting_hit_points)
      WORLD_WIDTH  = tostring(var.world_width)
      WORLD_HEIGHT = tostring(var.world_height)
    },
    local.has_table ? {
      TABLE_NAME = var.table.name
    } : {},
    local.has_gateway ? {
      API_BASE_URL = var.gateway.endpoint
    } : {},
  )
}

resource "aws_iam_role_policy_attachment" "table" {
  count = local.table_policy_arn != null ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = local.table_policy_arn
}
