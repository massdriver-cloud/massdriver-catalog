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
| `google_pubsub_subscription.bigquery` | Pub/Sub subscription | Created only when a Pub/Sub topic is wired. Delivers messages into a table in this dataset. |
| `google_bigquery_dataset_iam_member.pubsub_service_agent_data_editor` | IAM binding | Created only when a Pub/Sub topic is wired. Grants the Pub/Sub service agent `roles/bigquery.dataEditor` on this dataset. |
| `google_bigquery_dataset_iam_member.pubsub_service_agent_metadata_viewer` | IAM binding | Created only when a Pub/Sub topic is wired. Grants the Pub/Sub service agent `roles/bigquery.metadataViewer` on this dataset. |

This bundle does NOT create any workload IAM bindings. Consumer bundles (e.g., `gcp-cloud-run-service`, `gcp-vertex-workbench`) create their own service accounts and bind the appropriate roles on this dataset when connected on the canvas. The IAM bindings above are only for the Pub/Sub service agent, and only when a topic is wired.

## Connections

| Connection | Required | Artifact Type | How It Is Used |
|---|---|---|---|
| `gcp_authentication` | Yes | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `landing_zone` | Yes | `catalog-demo/gcp-landing-zone` | Provides `project_id` for resource placement |
| `pubsub_topic` | No | `catalog-demo/gcp-pubsub-topic` | When wired, creates a Pub/Sub BigQuery subscription that delivers messages into a table in this dataset |

### Optional: Pub/Sub BigQuery subscription

When you wire a `gcp-pubsub-topic` bundle to this bundle's `pubsub_topic` connection, the following happens on the next deploy:

1. The Pub/Sub service agent (`service-<project-num>@gcp-sa-pubsub.iam.gserviceaccount.com`) is granted `roles/bigquery.dataEditor` and `roles/bigquery.metadataViewer` on this dataset. These bindings are dataset-scoped, not project-wide.
2. A Pub/Sub subscription is created on the topic with BigQuery delivery configured to write into the table you specify.

The IAM bindings are removed when the topic is disconnected and the bundle is redeployed.

**The target table must already exist.** Pub/Sub does not create BigQuery tables. Create the table in the dataset before wiring the topic connection and deploying. If the table is absent, Terraform will succeed but the subscription will fail to deliver messages.

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

### BigQuery subscription parameters

These params appear in the form under **BigQuery Subscription Settings** and are only used when `pubsub_topic` is wired.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `bigquery_subscription.table_name` | string | — | Name of an existing table in this dataset. Pattern: `^[a-zA-Z0-9_]{1,1024}$`. Required when the topic is wired. |
| `bigquery_subscription.use_topic_schema` | boolean | `false` | When true, uses the Pub/Sub topic schema to map message fields to table columns. When false, writes raw bytes to a `data` column. |
| `bigquery_subscription.write_metadata` | boolean | `false` | When true, adds `subscription_name`, `message_id`, `publish_time`, and `attributes` columns to each row. Your table schema must include these columns. |
| `bigquery_subscription.drop_unknown_fields` | boolean | `false` | When true and `use_topic_schema` is enabled, silently drops message fields that are not in the table schema. When false, unknown fields send the message to the dead letter topic or drop it. |
| `bigquery_subscription.ack_deadline_seconds` | integer | `60` | Seconds Pub/Sub waits for BigQuery to acknowledge a message before re-delivering. Range 10–600. |

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
- When using the Pub/Sub BigQuery subscription feature, the target table named in `bigquery_subscription.table_name` must already exist in the dataset before deploying. This bundle does not create tables.
- When using the Pub/Sub BigQuery subscription feature, `pubsub.googleapis.com` must be enabled in the project.

## Presets

| Preset | Location | Default Table Expiration | Delete Protection |
|---|---|---|---|
| Dev | US | 30 days | Off |
| Staging | US | 90 days | Off |
| Production | US | None | On |
