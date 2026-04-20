# ─── Upstream Artifact IAM Auto-Binding ───────────────────────────────────────
#
# This file implements the "auto-binding" pattern for Workbench instances that
# consume upstream data artifacts. For each optional connection that IS wired on
# the canvas, Terraform grants THIS bundle's instance service account the
# minimum-privilege read-only role required to use that resource.
#
# The instance SA (google_service_account.instance in main.tf) is created by
# this bundle — not inherited from the landing zone. Each Workbench instance gets
# its own identity with bindings only to the resources it actually connects to.
#
# HOW IT WORKS
# ────────────
# Massdriver passes optional connections as null when not wired on the canvas,
# or as a plain object when wired. We detect presence with: var.<connection> != null
# Then use `count = var.<connection> != null ? 1 : 0` to conditionally create
# the binding. No connection → no IAM change. Add connection → binding appears
# on next deploy. Remove connection → binding is destroyed on next deploy.
#
# ROLES GRANTED
# ─────────────
# BigQuery dataset → roles/bigquery.dataViewer (read-only)
#   Allows the Workbench instance to SELECT from tables and list tables within
#   the dataset. Does NOT allow writing, updating, deleting rows, or creating
#   tables. This is intentionally restrictive — Workbench is a read-and-explore
#   environment, not a write path. If a notebook needs to write results back, a
#   separate BigQuery writer service (Cloud Run, Dataflow) should own that role.
#
# HARDCODED POLICY: read-only access for BigQuery dataset connections
# The decision to grant only roles/bigquery.dataViewer (not dataEditor) is
# deliberate and non-configurable. Workbench instances are interactive exploration
# tools — granting write access would allow ad-hoc schema mutations and data
# deletion from notebook cells, bypassing any pipeline governance. If a user needs
# write access to BigQuery from Workbench, they should authenticate with their
# personal GCP identity (via Application Default Credentials), which is subject
# to IAM policy for their user account and provides a full audit trail.

# ── BigQuery Dataset ───────────────────────────────────────────────────────────
# Grant the instance SA read-only access to the connected BigQuery dataset.
# Binding is dataset-scoped — propagates to all current and future tables.
# For table-level isolation, use google_bigquery_table_iam_member.

resource "google_bigquery_dataset_iam_member" "dataset_viewer" {
  count = var.bigquery_dataset != null ? 1 : 0

  project    = var.bigquery_dataset.project_id
  dataset_id = var.bigquery_dataset.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = local.instance_sa_member
}
