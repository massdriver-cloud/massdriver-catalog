# Single landing-zone artifact — combines network, enabled APIs, budget reference,
# and an informational summary of the IAM bindings applied at project level.
# Downstream bundles connect to this one artifact to get project_id, network, and
# the list of enabled APIs. Each consumer bundle creates its own workload SA.

resource "massdriver_artifact" "landing_zone" {
  field = "landing_zone"
  name  = "GCP Landing Zone ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    project_id = local.project_id

    network = {
      network_name      = var.network.network_name
      network_self_link = var.network.network_self_link
      region            = var.network.region
      primary_subnet    = var.network.primary_subnet
    }

    enabled_apis = var.enabled_apis

    # iam_bindings carries an informational summary of what project-level IAM was applied.
    # Downstream bundles do not consume this — it is an audit trail for operators.
    iam_bindings = [
      for binding in var.iam_bindings : {
        role   = binding.role
        member = binding.member
      }
    ]

    # budget is always present in the artifact for schema conformance.
    # When disabled, fields carry null/empty sentinel values so downstream
    # bundles can safely check landing_zone.budget.enabled before using them.
    budget = var.budget.enabled ? {
      enabled            = true
      budget_name        = google_billing_budget.environment[0].display_name
      billing_account_id = var.budget.billing_account_id
      amount_usd         = var.budget.amount
      } : {
      enabled            = false
      budget_name        = null
      billing_account_id = null
      amount_usd         = null
    }
  })
}
