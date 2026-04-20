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

# ─── Workload Service Account ─────────────────────────────────────────────────
# Runtime identity that data platform workloads (Cloud Run, Vertex Workbench,
# etc.) will run as. This is NOT the Terraform deploy credential.
# Downstream bundles read landing_zone.workload_identity.service_account_email
# and bind IAM roles to it on their own resources.

resource "google_service_account" "workload" {
  project      = local.project_id
  account_id   = var.service_account_name
  display_name = "Data Platform Workload Identity — ${local.name_prefix}"
  description  = "Runtime service account for data platform workloads. Managed by Massdriver landing zone ${local.name_prefix}."

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
