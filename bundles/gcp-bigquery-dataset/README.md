# gcp-bigquery-dataset

Google Cloud BigQuery dataset with configurable location, default table expiration, and delete protection. Use this bundle to provision a managed analytics dataset for data platform workloads — Cloud Run pipelines, Vertex Workbench notebooks, Dataflow jobs, and ad-hoc SQL analytics.

## Use Cases

- Centralized analytics dataset consumed by multiple downstream services with scoped IAM
- Dev/staging datasets with automatic table expiration to control storage cost growth
- Production datasets with delete protection to prevent accidental data loss

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_bigquery_dataset.main` | BigQuery dataset | Location, expiration, and delete protection set at provision time; Google-managed encryption |

This bundle does NOT create tables, subscriptions, or workload IAM bindings. Consumer bundles (e.g., `gcp-bigquery-table`, `gcp-cloud-run-service`, `gcp-vertex-workbench`) create their own resources and bind the appropriate roles on this dataset when connected on the canvas.

## Connections

| Connection | Required | Artifact Type | How It Is Used |
|---|---|---|---|
| `gcp_authentication` | Yes | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `landing_zone` | Yes | `catalog-demo/gcp-landing-zone` | Provides `project_id` for resource placement |

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-bigquery-dataset`

| Field | Type | Description |
|---|---|---|
| `project_id` | string | GCP project ID that owns the dataset |
| `dataset_id` | string | BigQuery dataset identifier (letters, digits, underscores) |
| `dataset_full_name` | string | Fully-qualified name in `<project>.<dataset>` form — use directly in SQL `FROM` clauses |
| `location` | string | BigQuery location where the dataset is stored |
| `friendly_name` | string or null | Human-readable display name if set; null otherwise |

Consumer bundles bind IAM roles using `dataset_id` and `project_id` from this artifact. Example patterns:

```hcl
# Read/write access (Cloud Run workers)
resource "google_bigquery_dataset_iam_member" "runtime_editor" {
  project    = var.bigquery_dataset.project_id
  dataset_id = var.bigquery_dataset.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.runtime.email}"
}

# Read-only access (Vertex Workbench notebooks)
resource "google_bigquery_dataset_iam_member" "dataset_viewer" {
  project    = var.bigquery_dataset.project_id
  dataset_id = var.bigquery_dataset.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.instance.email}"
}
```

## Compliance

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_81` | Requires CMEK on all BigQuery datasets. CMEK is intentionally out of scope for this bundle — Google-managed encryption is used. Checkov fires this check whenever a `default_encryption_configuration` block is absent. If CMEK is required, use a separate bundle with a KMS key connection. |

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- `bigquery.googleapis.com` must be enabled in the landing zone before deploying. Add it to `enabled_apis` in the `gcp-landing-zone` package.
- The `gcp_authentication` credential has `bigquery.admin` or equivalent IAM on the project.
- `dataset_id` is immutable after creation. Changing it requires destroying and recreating the dataset — all data is lost unless exported first.
- `default_table_expiration_days` applies only to tables created after the setting is applied. Existing tables are not affected.

## Presets

| Preset | Location | Default Table Expiration | Delete Protection |
|---|---|---|---|
| Dev | US | 30 days | Off |
| Staging | US | 90 days | Off |
| Production | US | None | On |
