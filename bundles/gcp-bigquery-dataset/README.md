# gcp-bigquery-dataset

Google Cloud BigQuery dataset with configurable location, default table expiration, and delete protection. Use this bundle to provision a managed analytics dataset for data platform workloads — Cloud Run pipelines, Vertex Workbench notebooks, Dataflow jobs, and ad-hoc SQL analytics. The landing zone's workload service account is automatically granted `dataEditor` access on the dataset.

## Purpose

- Provisions a BigQuery dataset at a chosen location with an immutable dataset ID
- Configures optional default table expiration to control storage cost growth in non-production environments
- Supports delete protection to prevent accidental dataset destruction in production
- Grants `roles/bigquery.dataEditor` to the landing zone's workload service account on the dataset
- Emits a `catalog-demo/gcp-bigquery-dataset` artifact so downstream bundles can reference the dataset without hard-coding project or dataset identifiers

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_bigquery_dataset.main` | BigQuery dataset | Location, expiration, and delete protection set at provision time; Google-managed encryption |
| `google_bigquery_dataset_iam_member.workload_data_editor` | IAM binding | Grants `roles/bigquery.dataEditor` to the landing zone workload SA on the dataset |

## Artifacts Consumed (Connections)

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id` and `workload_identity.service_account_email` for the dataEditor IAM binding |

## Artifacts Produced

The bundle publishes a `catalog-demo/gcp-bigquery-dataset` artifact with all fields needed for downstream bundles to query and load data.

| Field | Type | Description |
|---|---|---|
| `project_id` | string | GCP project ID that owns the dataset |
| `dataset_id` | string | BigQuery dataset identifier (letters, digits, underscores) |
| `dataset_full_name` | string | Fully-qualified name in `<project>.<dataset>` form — use directly in SQL `FROM` clauses |
| `location` | string | BigQuery location where the dataset is stored |
| `friendly_name` | string or null | Human-readable display name if set; null otherwise |

Downstream bundles that need read-only access should bind `roles/bigquery.dataViewer` on the dataset using `dataset_id` and `project_id` from this artifact. Bundles requiring full ownership should bind `roles/bigquery.dataOwner`.

## Compliance

### Hardcoded security baselines

BigQuery dataset-level IAM is the access control mechanism — there are no per-object ACLs to configure. All access to this dataset must go through IAM bindings, which this bundle manages via the `workload_data_editor` resource.

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_81` | Requires CMEK on all BigQuery datasets. CMEK is intentionally out of scope for this bundle — all datasets use Google-managed encryption, which is appropriate for the workloads this bundle targets. Checkov fires this check whenever a `default_encryption_configuration` block is absent, making it a false positive here. If CMEK is required for a specific workload, a separate bundle with a KMS connection should be used. |

### Production gating

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- `bigquery.googleapis.com` must be enabled in the landing zone before deploying this bundle. Add it to `enabled_apis` in the `gcp-landing-zone` package config.
- The `gcp_authentication` credential has `bigquery.admin` or equivalent IAM on the project.
- The landing zone's workload SA is granted `roles/bigquery.dataEditor` automatically; read-only or owner-level access for other consumers must be added by the downstream bundle.
- The dataset ID (`dataset_id`) is immutable after creation. Changing it requires destroying and recreating the dataset — all data will be lost unless exported first.

## Presets

| Preset | Location | Default Table Expiration | Delete Protection |
|---|---|---|---|
| Dev | US | 30 days | Off |
| Staging | US | 90 days | Off |
| Production | US | None (no expiration) | On |
