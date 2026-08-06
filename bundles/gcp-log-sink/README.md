# gcp-log-sink

Routes Cloud Logging entries from a GCP project to either a BigQuery dataset or a GCS bucket. Exactly one destination must be wired — the bundle enforces this with a Terraform precondition. The Google-managed sink writer service account is automatically granted the minimum required IAM role on the chosen destination.

## Use Cases

- Persistent audit log storage: pipe `cloudaudit.googleapis.com/activity` to GCS for long-term retention at low cost.
- Log-based analytics: route application or infrastructure logs to BigQuery for SQL queries and dashboards.
- Error alerting pipeline: filter `severity >= ERROR` to BigQuery, then query from Vertex Workbench or a BI tool.

## Resources Created

| Resource | Description |
|---|---|
| `google_logging_project_sink.main` | Project-scoped Cloud Logging sink with unique writer identity |
| `google_bigquery_dataset_iam_member.sink_writer` | (BigQuery only) Grants sink SA `roles/bigquery.dataEditor` on the dataset |
| `google_storage_bucket_iam_member.sink_writer` | (GCS only) Grants sink SA `roles/storage.objectCreator` on the bucket |

## Connections

### Required

- **GCP Credentials** (`gcp-service-account`) — service account used by Terraform to create and manage the sink.
- **GCP Landing Zone** (`catalog-demo/gcp-landing-zone`) — provides the project ID where the sink is created.

### Optional Destinations (exactly one must be wired)

- **BigQuery Dataset** (`catalog-demo/gcp-bigquery-dataset`) — route logs to this dataset. Logs land in tables named after the log type; date-partitioned when `use_partitioned_tables` is enabled.
- **GCS Bucket** (`catalog-demo/gcp-storage-bucket`) — route logs to this bucket. Cloud Logging batches entries hourly into JSON files organized by date and hour.

If neither or both destinations are wired, `tofu plan` will fail with a clear error message.

## Artifact Produced

`catalog-demo/gcp-log-sink` — carries `project_id`, `sink_name`, `destination`, `writer_identity`, and `destination_type`. Downstream bundles rarely need to consume this artifact directly; it is published for observability and chaining.

## Compliance

Log sinks are low-risk infrastructure. No Checkov skips are expected. `halt_on_failure` is set to block deployments to `prod`, `prd`, and `production` environments on any compliance failure.

## Presets

| Preset | Filter | Partitioned Tables | Notes |
|---|---|---|---|
| Error Logs to BigQuery | `severity >= ERROR` | Yes | Recommended starting point for BigQuery destinations |
| Audit Logs to GCS | `logName = "projects/PROJECT/logs/cloudaudit.googleapis.com%2Factivity"` | No | Update PROJECT to your GCP project ID before deploying |
| All Logs (no filter) | (empty) | Yes | Routes every log entry — can generate significant storage costs |

## Assumptions

- This bundle creates a **project-level** sink. It does NOT capture logs from child projects, folders, or the organization. Folder or org sinks are out of scope.
- `unique_writer_identity = true` is non-negotiable. Sharing the project-level logging SA across sinks would mean IAM grants on one sink's destination affect all other sinks.
- Filter changes take effect immediately but do NOT backfill historical logs. Logs written before the filter change are not re-routed.
