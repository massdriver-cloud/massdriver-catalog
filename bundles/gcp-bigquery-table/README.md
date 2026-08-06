# gcp-bigquery-table

Google Cloud BigQuery table with configurable schema and optional Pub/Sub subscription delivery. Use this bundle to provision a managed table inside an existing BigQuery dataset — with or without a Pub/Sub subscription routing messages into it.

## Use Cases

- Pub/Sub-to-BigQuery pipeline: wire a topic to this table and messages land automatically
- Custom-schema analytics table: define your own BigQuery schema JSON and deploy
- Production tables with deletion protection to prevent accidental data loss

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_bigquery_table.main` | BigQuery table | Schema is either Pub/Sub-compatible (5 standard columns) or user-provided JSON |
| `google_bigquery_table_iam_member.pubsub_service_agent_data_editor` | IAM binding | Created only when a Pub/Sub topic is wired. Grants the Pub/Sub service agent `roles/bigquery.dataEditor` on this table. |
| `google_bigquery_table_iam_member.pubsub_service_agent_metadata_viewer` | IAM binding | Created only when a Pub/Sub topic is wired. Grants the Pub/Sub service agent `roles/bigquery.metadataViewer` on this table. |
| `google_pubsub_subscription.bigquery` | Pub/Sub subscription | Created only when a Pub/Sub topic is wired. Delivers messages from the topic into this table. |

IAM bindings are table-scoped (not dataset-wide) for least privilege. The bindings are removed when the `pubsub_topic` connection is unwired and the bundle is redeployed.

## Connections

| Connection | Required | Artifact Type | How It Is Used |
|---|---|---|---|
| `gcp_authentication` | Yes | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `bigquery_dataset` | Yes | `catalog-demo/gcp-bigquery-dataset` | Provides `project_id` and `dataset_id` for table placement |
| `pubsub_topic` | No | `catalog-demo/gcp-pubsub-topic` | When wired, creates a Pub/Sub BigQuery subscription that delivers messages into this table |

## Schema Modes

**`pubsub_default`** (recommended when wiring a Pub/Sub topic): Creates the table with five standard Pub/Sub columns:
- `subscription_name STRING` — name of the subscription that delivered the message
- `message_id STRING` — unique message identifier assigned by Pub/Sub
- `publish_time TIMESTAMP` — time the message was published to the topic
- `data STRING` — message payload (base64-decoded when `use_topic_schema = false`)
- `attributes JSON` — key-value attributes attached to the message

**`custom_schema`**: Provide the full BigQuery schema as a JSON array in the `schema_json` parameter. Each field descriptor requires at minimum `name` and `type`. Example:
```json
[
  {"name": "event_type", "type": "STRING", "mode": "NULLABLE"},
  {"name": "payload",    "type": "JSON",   "mode": "NULLABLE"},
  {"name": "created_at", "type": "TIMESTAMP", "mode": "NULLABLE"}
]
```

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-bigquery-table`

| Field | Type | Description |
|---|---|---|
| `project_id` | string | GCP project ID that owns the table |
| `dataset_id` | string | BigQuery dataset containing this table |
| `table_id` | string | BigQuery table identifier |
| `table_full_name` | string | Fully-qualified name in `<project>.<dataset>.<table>` form — use directly in SQL `FROM` clauses |

Consumer bundles bind IAM roles using the table fields from this artifact. Example:

```hcl
resource "google_bigquery_table_iam_member" "reader" {
  project    = var.bigquery_table.project_id
  dataset_id = var.bigquery_table.dataset_id
  table_id   = var.bigquery_table.table_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.runtime.email}"
}
```

## Compliance

No Checkov checks are skipped. All findings in this bundle are resolved in Terraform directly.

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- `bigquery.googleapis.com` must be enabled in the landing zone before deploying.
- The `gcp_authentication` credential has `bigquery.admin` or equivalent IAM on the project.
- `table_id` is immutable after creation. Changing it requires destroying and recreating the table — all data is lost unless exported first.
- When wiring a `pubsub_topic`, `pubsub.googleapis.com` must also be enabled in the project.
- The BigQuery subscription target table (this table) must exist before Pub/Sub can validate the subscription. This bundle creates the table first, so order-of-operations is handled automatically.

## Presets

| Preset | Schema Mode | Deletion Protection |
|---|---|---|
| Pub/Sub Default | pubsub_default | On |
| Custom Schema | custom_schema | On |
