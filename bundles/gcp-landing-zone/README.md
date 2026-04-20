# gcp-landing-zone

Project-level governance construct for a GCP data platform. Deploy this once per environment before any workload bundles.

- Enables GCP service APIs required by your data platform stack
- Applies project-level IAM bindings for human operators and groups (e.g., `roles/viewer` to `group:data-analysts@example.com`)
- Enforces org-policy guardrails at the project level (e.g., disable SA key creation, block public GCS access)
- Optionally configures a billing budget with spend-threshold email alerts
- Folds the input `gcp-network` artifact into its own `landing_zone` output so downstream bundles need only one connection

**This bundle does NOT provision workload service accounts.** Each consumer bundle (Cloud Run, Vertex Workbench) creates its own runtime SA with least-privilege bindings on the specific resources it uses. Project-level IAM here is for human operators and group access only.

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_project_service.apis` | API enablement (one per API) | `disable_on_destroy = false` — removing an API from params does not disable it in GCP |
| `google_project_iam_member.operators` | Project IAM bindings | One resource per `{role, member}` entry; additive, non-authoritative |
| `google_project_organization_policy.guardrails` | Org policy constraints | Project-scoped; one resource per constraint |
| `google_billing_budget.environment` | Billing budget | Created only when `budget.enabled = true` |
| `google_monitoring_notification_channel.budget_email` | Email alert channel | Created only when budget is enabled and `notification_emails` is non-empty |

## Connections

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `network` | `catalog-demo/gcp-network` | Network metadata passed through into the `landing_zone` artifact for downstream use |

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-landing-zone`

Downstream bundles connect to this one artifact to get everything they need.

| Field | Description |
|---|---|
| `project_id` | GCP project ID |
| `network.network_name` | VPC name (passed through from input) |
| `network.network_self_link` | VPC self-link URI |
| `network.region` | Subnet region |
| `network.primary_subnet.name` | Subnet name |
| `network.primary_subnet.cidr` | Subnet CIDR range |
| `network.primary_subnet.self_link` | Subnet self-link URI |
| `enabled_apis` | List of APIs enabled by this landing zone |
| `iam_bindings` | Informational list of project-level `{role, member}` bindings applied — audit trail only, not consumed by downstream bundles |
| `budget.enabled` | Whether a budget was configured |
| `budget.budget_name` | Budget display name (null when disabled) |
| `budget.billing_account_id` | Billing account the budget is attached to (null when disabled) |
| `budget.amount_usd` | Monthly budget limit in USD (null when disabled) |

## IAM Pattern for Consumer Bundles

Each consumer bundle creates its own service account and binds it to the specific resources it uses. The landing zone does not provide or share a workload SA. Example:

```hcl
resource "google_service_account" "runtime" {
  project      = var.landing_zone.project_id
  account_id   = "${var.md_metadata.name_prefix}-sa"
  display_name = "Runtime SA for ${var.md_metadata.name_prefix}"
}

resource "google_bigquery_dataset_iam_member" "runtime_editor" {
  dataset_id = var.bigquery_dataset.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.runtime.email}"
}
```

The artifact policy comments in `gcp-pubsub-topic`, `gcp-bigquery-dataset`, and `gcp-storage-bucket` source files are the canonical role-binding reference.

## Compliance

### Hardcoded security controls

| Control | Mechanism | Reason |
|---|---|---|
| Additive IAM only | `google_project_iam_member` (per-binding, non-authoritative) | Avoids clobbering bindings set by GCP defaults or other automation |
| APIs not disabled on destroy | `disable_on_destroy = false` | Prevents accidental disruption of other resources that depend on the same APIs |

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_118` | Skipped on `google_project_service` — API enablement resources do not accept IAM policies |

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- The GCP project already exists — this bundle does not create projects.
- The `gcp_authentication` credential has `iam.admin`, `serviceusage.serviceUsageAdmin`, `orgpolicy.policy.set` (project scope), and (if using budgets) `billing.budgets.create` IAM.
- Cloud Billing must be linked to the project before budgets can be created.
- `billingbudgets.googleapis.com` must be in `enabled_apis` when `budget.enabled = true`.

## Presets

| Preset | Budget | Notable APIs |
|---|---|---|
| Standard (no budget) | Disabled | compute, iam, resourcemanager, serviceusage, run, bigquery, storage, pubsub, aiplatform, notebooks, logging, monitoring |
| Standard (with budget) | Enabled — $500/mo, alerts at 50%/90%/100% | All of the above plus billingbudgets; example org policies: disable SA keys, block public GCS, require OS Login |
