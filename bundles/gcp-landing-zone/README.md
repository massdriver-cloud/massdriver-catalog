# gcp-landing-zone

Environment-foundational construct for a GCP data platform. Deploy this once per environment before any workload bundles. It:

- Enables GCP service APIs required by your data platform stack
- Provisions a **workload runtime service account** that Cloud Run, Vertex Workbench, and other services run as
- Optionally configures a **billing budget** with spend-threshold email alerts
- Folds the input `gcp-network` artifact into its own `landing_zone` output so downstream bundles need only one connection instead of wiring network and identity separately

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_project_service.apis` | API enablement (one per API) | `disable_on_destroy = false` to avoid disrupting other resources |
| `google_service_account.workload` | Workload runtime SA | Created with no project-level roles; downstream bundles bind roles on their own resources |
| `google_billing_budget.environment` | Billing budget | Created only when `budget.enabled = true` |
| `google_monitoring_notification_channel.budget_email` | Email alert channel | Created only when budget is enabled and `notification_emails` is non-empty |

## Artifacts Consumed (Connections)

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `network` | `catalog-demo/gcp-network` | Network metadata passed through into the `landing_zone` artifact for downstream use |

## Artifacts Produced

The bundle publishes a single `catalog-demo/gcp-landing-zone` artifact. Downstream bundles connect to this one artifact to get everything they need.

| Field | Description |
|---|---|
| `project_id` | GCP project ID |
| `network.network_name` | VPC name (passed through from input) |
| `network.network_self_link` | VPC self-link URI |
| `network.region` | Subnet region |
| `network.primary_subnet.name` | Subnet name |
| `network.primary_subnet.cidr` | Subnet CIDR range |
| `network.primary_subnet.self_link` | Subnet self-link URI |
| `workload_identity.service_account_email` | Runtime SA email — used by downstream bundles to bind IAM roles |
| `workload_identity.service_account_id` | Runtime SA unique ID |
| `workload_identity.service_account_name` | Runtime SA resource name |
| `enabled_apis` | List of APIs that were enabled |
| `budget.enabled` | Whether a budget was configured |
| `budget.budget_name` | Budget display name (null when disabled) |
| `budget.billing_account_id` | Billing account the budget is attached to (null when disabled) |
| `budget.amount_usd` | Monthly budget limit in USD (null when disabled) |

## Downstream IAM Pattern

Each downstream bundle reads `landing_zone.workload_identity.service_account_email` and grants the minimum required roles on its own resources. Example for a BigQuery dataset:

```hcl
resource "google_bigquery_dataset_iam_member" "workload" {
  dataset_id = google_bigquery_dataset.main.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${var.landing_zone.workload_identity.service_account_email}"
}
```

The workload SA is intentionally created with no project-level roles. Do not add broad roles here.

## Compliance

### Hardcoded security controls

| Control | Mechanism | Reason |
|---|---|---|
| No broad IAM roles on workload SA | SA created with no bindings | Downstream bundles use least-privilege per-resource bindings |
| APIs not disabled on destroy | `disable_on_destroy = false` | Prevents accidental disruption of other resources that depend on the same APIs |

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_118` | Skipped on `google_project_service` — API enablement resources do not accept IAM policies |

### Production gating

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- The GCP project already exists — this bundle does not create projects.
- The `gcp_authentication` credential has `iam.serviceAccountAdmin`, `serviceusage.serviceUsageAdmin`, and (if using budgets) `billing.budgets.create` IAM.
- Cloud Billing must be linked to the project before budgets can be created.
- `billingbudgets.googleapis.com` must be in `enabled_apis` when `budget.enabled = true`.

## Presets

| Preset | Budget | Notable APIs |
|---|---|---|
| Standard (no budget) | Disabled | compute, iam, resourcemanager, serviceusage, run, bigquery, storage, aiplatform, notebooks, logging, monitoring |
| Standard (with budget) | Enabled — $500/mo, alerts at 50%/90%/100% | All of the above plus billingbudgets |
