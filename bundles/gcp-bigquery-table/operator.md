---
templating: mustache
---

# GCP BigQuery Table — Operator Runbook

## Non-obvious constraints

**Table ID is immutable.** `table_id` cannot be changed in-place. To rename: export the table data, destroy the package, reprovision with the new ID, reload from GCS. Treat the table ID as permanent.

**Deletion protection requires a two-step destroy.** When `deletion_protection = true`, the destroy will fail with a "Table cannot be deleted" error. To decommission:
1. Set `deletion_protection = false` in the package config and deploy.
2. Then run the destroy.

**Schema evolution is limited.** BigQuery supports a narrow set of in-place schema changes: adding new columns at the end of the schema, relaxing a field from REQUIRED to NULLABLE, and a few others. Changing column types, renaming columns, or reordering columns requires dropping and recreating the table — all data is lost unless exported first. Plan your schema carefully before first deploy.

**Pub/Sub subscription target table must exist before the subscription can deliver messages.** This bundle creates the table before the subscription, so order-of-operations is handled automatically. However, if you destroy and recreate the table independently, redeploy this bundle to recreate the subscription and its IAM bindings.

**Pub/Sub IAM bindings are table-scoped and removed on disconnect.** When you unwire the `pubsub_topic` connection and redeploy, Terraform removes the two service agent IAM bindings from this table. No dataset-level or project-level IAM is modified. Existing data in the table is not affected — only new message delivery stops.

**Schema mismatch routes messages to dead letter or drops them.** When `use_topic_schema = true` and a message contains fields not in the table schema, behavior depends on `drop_unknown_fields`. If `drop_unknown_fields = false` (the default), the message is routed to the dead letter topic if one is configured on the source topic, or dropped. If `drop_unknown_fields = true`, the extra fields are silently discarded and the message is delivered.

**IAM propagation is eventually consistent.** The Pub/Sub subscription creation depends on IAM bindings that may not have propagated yet. The `depends_on` in this bundle mitigates timing issues, but if the subscription creation fails during a first deploy, a redeploy will resolve it.

## Troubleshooting

**Pub/Sub subscription stuck — messages not appearing in BigQuery.**
```bash
# Check subscription delivery status and error details
gcloud pubsub subscriptions describe {{artifacts.bigquery_table.table_id}}-bq \
  --project={{artifacts.bigquery_table.project_id}}

# Confirm table exists
bq show --format=prettyjson {{artifacts.bigquery_table.table_full_name}}

# Confirm IAM bindings (look for gcp-sa-pubsub entries)
bq get-iam-policy {{artifacts.bigquery_table.table_full_name}}
```
Common causes: table schema mismatch with message fields, `use_topic_schema = true` but topic has no schema, IAM bindings not yet propagated (redeploy to fix), or `pubsub.googleapis.com` not enabled.

**Pub/Sub subscription creation fails with permission error during deploy.**
IAM propagation is eventually consistent — wait 30–60 seconds and redeploy. The `depends_on` in this bundle mitigates but does not eliminate this race.

**Messages delivered but columns are all null.**
If `use_topic_schema = false` (default), messages are written as raw bytes to the `data` column. Enable `write_metadata = true` so metadata columns (subscription_name, message_id, publish_time, attributes) are populated. Query the `data` column directly for the message payload.

**Deploy fails with "bigquery.googleapis.com has not been used in project."**
Add `bigquery.googleapis.com` to `enabled_apis` in the `gcp-landing-zone` package, redeploy the landing zone, wait ~60 seconds, then retry.

**Deploy fails with "pubsub.googleapis.com has not been used in project."**
Add `pubsub.googleapis.com` to `enabled_apis` in the `gcp-landing-zone` package, redeploy the landing zone, wait ~60 seconds, then retry.

**Permission denied on table access.**
```bash
bq get-iam-policy {{artifacts.bigquery_table.table_full_name}}
```
The required member should have `roles/bigquery.dataEditor` for read/write or `roles/bigquery.dataViewer` for read-only. If the binding is absent, redeploy the consumer bundle with the table wired on the canvas.

## Day-2 operations

**Querying the table:**
```bash
bq query --project_id={{artifacts.bigquery_table.project_id}} \
  'SELECT * FROM `{{artifacts.bigquery_table.table_full_name}}` LIMIT 100'
```

**Inspecting table schema and row count:**
```bash
bq show --format=prettyjson {{artifacts.bigquery_table.table_full_name}}
bq query --project_id={{artifacts.bigquery_table.project_id}} \
  'SELECT COUNT(*) FROM `{{artifacts.bigquery_table.table_full_name}}`'
```

**Exporting table data before destroying:**
```bash
bq extract \
  --destination_format=NEWLINE_DELIMITED_JSON \
  {{artifacts.bigquery_table.table_full_name}} \
  gs://<backup-bucket>/{{artifacts.bigquery_table.dataset_id}}/{{artifacts.bigquery_table.table_id}}/*.jsonl
```

**Replaying missed Pub/Sub messages from a timestamp:**
```bash
gcloud pubsub subscriptions seek <subscription-name> \
  --time=$(date -u +%Y-%m-%dT%H:%M:%SZ -d "1 hour ago") \
  --project={{artifacts.bigquery_table.project_id}}
```

## Useful commands

```bash
# Show table schema and metadata
bq show --format=prettyjson {{artifacts.bigquery_table.table_full_name}}

# Show IAM policy on the table
bq get-iam-policy {{artifacts.bigquery_table.table_full_name}}

# List all subscriptions on the parent topic
gcloud pubsub topics list-subscriptions <topic-name> \
  --project={{artifacts.bigquery_table.project_id}}

# Describe the BigQuery subscription (delivery config + error state)
gcloud pubsub subscriptions describe <subscription-name> \
  --project={{artifacts.bigquery_table.project_id}}

# Run an ad-hoc query
bq query --project_id={{artifacts.bigquery_table.project_id}} \
  'SELECT COUNT(*) FROM `{{artifacts.bigquery_table.table_full_name}}`'
```
