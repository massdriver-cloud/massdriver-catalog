# Single landing-zone artifact — combines network, workload identity, enabled APIs,
# and budget reference. Downstream bundles connect to this one artifact instead of
# wiring network and identity connections separately.

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

    workload_identity = {
      service_account_email = google_service_account.workload.email
      service_account_id    = google_service_account.workload.unique_id
      service_account_name  = google_service_account.workload.name
    }

    enabled_apis = var.enabled_apis

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
