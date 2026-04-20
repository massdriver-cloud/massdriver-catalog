terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

provider "google" {
  project     = var.gcp_authentication.project_id
  credentials = jsonencode(var.gcp_authentication)
}

provider "google-beta" {
  project     = var.gcp_authentication.project_id
  credentials = jsonencode(var.gcp_authentication)
}

locals {
  project_id  = var.gcp_authentication.project_id
  name_prefix = var.md_metadata.name_prefix
}

# ─── Service APIs ─────────────────────────────────────────────────────────────

resource "google_project_service" "apis" {
  for_each = toset(var.enabled_apis)

  project = local.project_id
  service = each.value

  # Do not disable the API on destroy — other resources in the project may depend on it
  disable_on_destroy = false
}

# ─── Project IAM Bindings (human operators / groups) ─────────────────────────
# Non-authoritative (google_project_iam_member) — one resource per binding.
# This will NOT remove any bindings set outside of Terraform.
# Intended for humans and groups who need project-level access (e.g., viewers,
# billing admins). Workload service accounts are NOT managed here — each consumer
# bundle creates its own runtime SA.

resource "google_project_iam_member" "operators" {
  for_each = {
    for binding in var.iam_bindings :
    "${binding.role}/${binding.member}" => binding
  }

  project = local.project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [google_project_service.apis]
}

# ─── Org Policy Guardrails (project-scoped) ───────────────────────────────────
# Applied at the project level — does not affect other projects in the org.
# Boolean constraints: enforce = true/false as configured.
# List constraints (e.g. vmExternalIpAccess): enforced=true → deny_all policy.
#
# Common useful constraints:
#   constraints/iam.disableServiceAccountKeyCreation  — prevents user-managed SA keys
#   constraints/storage.publicAccessPrevention        — blocks public GCS bucket access
#   constraints/compute.requireOsLogin                — enforces OS Login on all VMs
#   constraints/compute.vmExternalIpAccess            — deny all external IPs on VMs

resource "google_project_organization_policy" "guardrails" {
  for_each = {
    for policy in var.org_policies :
    policy.constraint => policy
  }

  project    = local.project_id
  constraint = each.value.constraint

  boolean_policy {
    enforced = each.value.enforced
  }

  depends_on = [google_project_service.apis]
}

# ─── Billing Budget ───────────────────────────────────────────────────────────
# Requires billingbudgets.googleapis.com enabled and billing.budgets.create IAM.
# Only created when var.budget.enabled == true. The billingbudgets.googleapis.com
# API should be included in enabled_apis when budget is enabled.

data "google_project" "current" {
  project_id = local.project_id

  depends_on = [google_project_service.apis]
}

resource "google_billing_budget" "environment" {
  count = var.budget.enabled ? 1 : 0

  billing_account = var.budget.billing_account_id
  display_name    = "Budget — ${local.name_prefix}"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(floor(var.budget.amount))
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget.threshold_percentages
    content {
      # threshold_percentages are stored as whole numbers (50, 90, 100) in params
      # and converted to fractions (0.5, 0.9, 1.0) for the GCP API
      threshold_percent = threshold_rules.value / 100
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = length(google_monitoring_notification_channel.budget_email) > 0 ? [google_monitoring_notification_channel.budget_email[0].id] : []
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.apis]
}

# ─── Budget Email Alert via Monitoring Notification Channel ──────────────────
# Only provisioned when budget is enabled AND notification_emails is non-empty.
# Emails are optional — GCP will still send to billing admins via disable_default_iam_recipients=false.

resource "google_monitoring_notification_channel" "budget_email" {
  count = var.budget.enabled && length(var.budget.notification_emails) > 0 ? 1 : 0

  project      = local.project_id
  display_name = "Budget Alert — ${local.name_prefix}"
  type         = "email"

  labels = {
    email_address = var.budget.notification_emails[0]
  }

  depends_on = [google_project_service.apis]
}
