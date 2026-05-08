---
templating: mustache
---

# GCP BigQuery Dataset — Operator Runbook

## Non-obvious constraints

**Dataset ID is immutable.** `dataset_id` cannot be changed in-place. To rename: export all tables, destroy the package, reprovision with the new ID, reload from GCS. Treat the dataset ID as permanent.

**Location is immutable.** Datasets cannot be moved between regions after creation. To change location: export all tables (`bq extract` to GCS), destroy the package, reprovision in the new location, reload. Budget for data transfer costs and downtime.

**`default_table_expiration_ms` applies to NEW tables only.** Changing this on an existing dataset does not expire or modify existing tables. To set expiration on an existing table, update it directly via `bq update`.

**Delete protection requires a two-step destroy.** When `delete_protection = true`, the destroy will fail. To decommission:
1. Set `delete_protection = false` in the package config and deploy.
2. Then run the destroy.

**Dataset-level IAM propagates to all tables, current and future.** For row-level or table-level isolation, use BigQuery row-level security policies or bind IAM at the table level separately.

**Consumer bundles are responsible for their own IAM bindings.** Consumer bundles bind their own service accounts to this dataset. If a service can't query or load data, the IAM binding is missing from the consumer bundle — not from here.

**Cross-region queries are not supported.** BigQuery cannot join tables in different regions in a single query. Use Storage Transfer Service or BigQuery Data Transfer Service to replicate data first.

## Troubleshooting

**Permission denied on dataset access.**
```bash
bq get-iam-policy {{artifacts.bigquery_dataset.dataset_full_name}}
```
The required member should have `roles/bigquery.dataEditor` for read/write or `roles/bigquery.dataViewer` for read-only. If the binding is absent, redeploy the consumer bundle with the dataset wired on the canvas.

**Quota exceeded on concurrent jobs or daily bytes scanned.**
BigQuery per-project quotas are not manageable through this bundle. Check the BigQuery quota dashboard in the GCP console and request increases if needed.

**Streaming insert rows not expiring as expected.**
Rows inserted via the streaming API have a delay before table expiration recalculation applies. Batch loads have no such lag.

**Deploy fails with "bigquery.googleapis.com has not been used in project."**
Add `bigquery.googleapis.com` to `enabled_apis` in the `gcp-landing-zone` package, redeploy the landing zone, wait ~60 seconds, then retry.

**Table schema mismatch or load failure.**
```bash
bq show --format=prettyjson {{artifacts.bigquery_dataset.dataset_full_name}}.<table_id>
```

## Day-2 operations

**Setting expiration on an existing table** (default expiration doesn't backfill):
```bash
# Set expiration 30 days from now
EXPIRY=$(date -d "+30 days" +%s000 2>/dev/null || date -v+30d +%s000)
bq update --expiration=$EXPIRY {{artifacts.bigquery_dataset.dataset_full_name}}.<table_id>

# Remove expiration from a table
bq update --expiration=0 {{artifacts.bigquery_dataset.dataset_full_name}}.<table_id>
```

**Exporting all tables before destroying the dataset:**
```bash
for TABLE in $(bq ls --format=csv {{artifacts.bigquery_dataset.dataset_full_name}} | tail -n +2 | cut -d, -f1); do
  bq extract \
    --destination_format=NEWLINE_DELIMITED_JSON \
    {{artifacts.bigquery_dataset.dataset_full_name}}.$TABLE \
    gs://<backup-bucket>/{{artifacts.bigquery_dataset.dataset_id}}/$TABLE/*.jsonl
done
```

**Granting read-only access to another principal** (outside Terraform — overwritten on next apply):
```bash
bq add-iam-policy-binding \
  --member="serviceAccount:<sa-email>" \
  --role="roles/bigquery.dataViewer" \
  {{artifacts.bigquery_dataset.dataset_full_name}}
```

## Useful commands

```bash
# Show dataset metadata (location, expiration, labels)
bq show --format=prettyjson {{artifacts.bigquery_dataset.dataset_full_name}}

# List tables in the dataset
bq ls {{artifacts.bigquery_dataset.dataset_full_name}}

# Show IAM policy on the dataset
bq get-iam-policy {{artifacts.bigquery_dataset.dataset_full_name}}

# Show a specific table's schema and metadata
bq show --format=prettyjson {{artifacts.bigquery_dataset.dataset_full_name}}.<table_id>

# Check a table's current expiration time
bq show --format=prettyjson {{artifacts.bigquery_dataset.dataset_full_name}}.<table_id> | jq '.expirationTime'

# Run an ad-hoc query (billed to project)
bq query --project_id={{artifacts.bigquery_dataset.project_id}} \
  'SELECT COUNT(*) FROM `{{artifacts.bigquery_dataset.dataset_full_name}}.<table_id>`'
```
