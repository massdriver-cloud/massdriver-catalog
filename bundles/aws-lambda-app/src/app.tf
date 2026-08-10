# Application wiring: what the function knows about the resources linked to it.

locals {
  has_assets = try(var.assets.name, null) != null

  # The asset bucket publishes real IAM policies. The form shows their friendly
  # names ("read", "write", "admin"); this maps the chosen name back to the ARN
  # so the execution role can attach it.
  asset_policy_arn = local.has_assets && var.asset_bucket_access != null ? one([
    for p in var.assets.policies : p.id if p.name == var.asset_bucket_access
  ]) : null

  # Handed to the function as environment variables so the code reads its
  # configuration from the environment instead of hardcoding resource names.
  # Encrypted at rest with this bundle's KMS key.
  environment_variables = merge(
    {
      LOG_LEVEL = var.log_level
      APP_ENV   = var.md_metadata.default_tags["md-target"]
    },
    local.has_assets ? {
      ASSET_BUCKET   = var.assets.name
      ASSET_ENDPOINT = try(var.assets.endpoint, "")
      ASSET_REGION   = try(var.assets.region, var.region)
    } : {},
  )
}

resource "aws_iam_role_policy_attachment" "assets" {
  count = local.asset_policy_arn != null ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = local.asset_policy_arn
}
