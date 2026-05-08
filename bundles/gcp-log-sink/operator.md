# gcp-log-sink — Operator Runbook

## Non-obvious constraints

**Project scope only.** This sink captures logs from the project specified in the landing zone connection. Logs from other projects, child folders, or the organization are not captured. Folder-level and org-level sinks require a different Terraform resource (`google_logging_folder_sink` / `google_logging_organization_sink`) and are out of scope for this bundle.

**`unique_writer_identity` is locked to `true`.** The Google-managed writer SA is unique per sink. If set to `false`, Cloud Logging would use the shared `cloud-logs@system.gserviceaccount.com` SA, which cannot be individually scoped to a single dataset or bucket. Changing this after the sink is created requires destroy and recreate — the writer identity changes.

**Writer identity is generated at sink creation.** The `writer_identity` SA email is not known before `tofu apply`. It is provisioned by Cloud Logging when the sink resource is created. If the sink is destroyed and recreated (not updated in place), a NEW writer identity SA is generated and all prior IAM bindings on the destination become stale. This bundle re-creates the IAM binding from the new identity, but any manually added bindings on the destination will not.

**Filter changes are non-backfilling.** Updating the `filter` takes effect immediately for new log entries. Historical logs already written to the destination are not touched. Entries that were routed before the filter change remain in BigQuery or GCS permanently.

**BigQuery schema is auto-created and can drift.** Cloud Logging infers table schema from log entry structure. If Google changes the structure of a system log (e.g., adds or renames a field), existing tables are not migrated. Queries relying on specific field paths may break. Use `SELECT *` with caution in production pipelines.

**GCS batching latency.** Cloud Logging batches log entries hourly before writing to GCS. The sink is not suitable for near-real-time querying or alerting. Use BigQuery with `use_partitioned_tables = true` for latency-sensitive use cases.

**Exactly-one destination is a hard constraint.** The Terraform precondition blocks plan if both or neither optional connections are wired. This check fires before any API calls — you will see the error in the deployment log from the `tofu plan` step.

## Troubleshooting

**"precondition failed: Connect either a BigQuery dataset or a Storage bucket"** — Exactly one of the two optional connections (`bigquery_dataset`, `storage_bucket`) must be wired on the canvas. Check the canvas wiring and re-deploy.

**Sink exists but no logs appear in destination** — Verify the filter is correct by testing it in the Logs Explorer (`console.cloud.google.com/logs/query`) against live traffic before applying it to the sink. An overly restrictive filter results in a valid sink that routes nothing.

**IAM error: "The caller does not have permission on the resource"** — The sink writer identity SA needs time to propagate after creation. If IAM bindings were applied but the sink was just created, wait 60-90 seconds and check again. If the sink was destroyed and recreated, the writer identity changed — check the artifact `writer_identity` field and verify the IAM binding reflects the new SA.

**BigQuery tables not appearing after deploy** — Cloud Logging creates tables lazily: the first matching log entry triggers table creation. If no logs match the filter, no tables appear. Confirm by checking Logs Explorer for matching entries, then wait up to 5 minutes.

**GCS files not appearing** — Cloud Logging writes hourly. Wait at least 90 minutes after deploy before concluding there is a problem. Check the Logs Explorer for entries matching the filter first.

**"ALREADY_EXISTS" error on sink creation** — A sink with the same name (derived from `md_metadata.name_prefix`) already exists in the project. This happens if a previous deployment left a sink that Terraform state does not track. Import the existing sink: `tofu import google_logging_project_sink.main projects/PROJECT/sinks/SINK_NAME`.

## Day-2 operations

**Updating the filter** — Change the `filter` param in the package config and deploy. The sink is updated in place. Filter changes are immediate for new log entries. No restart or recreate needed.

**Adding an exclusion** — Add an entry to the `exclusions` array and deploy. Exclusions are applied after the sink filter. Use the Logs Explorer to validate the exclusion filter matches what you intend before deploying to production.

**Switching destinations** — Changing from BigQuery to GCS (or vice versa) requires the opposite connection to be wired AND the currently wired connection to be unwired simultaneously. The precondition blocks any state where both or neither are active. Execute the connection change and re-deploy in a single operation. The old IAM binding is removed and a new one is created. The sink name and writer identity do not change.

**Decommissioning** — Destroying the bundle removes the sink and the IAM binding. Log entries already in the destination (BigQuery tables or GCS objects) are NOT deleted — they remain in the destination resource and accrue storage cost until manually removed.

## Useful Commands

```bash
# List sinks in the project
gcloud logging sinks list --project=PROJECT_ID

# Describe a specific sink
gcloud logging sinks describe SINK_NAME --project=PROJECT_ID

# Check sink writer identity (useful for manual IAM debugging)
gcloud logging sinks describe SINK_NAME --project=PROJECT_ID --format="value(writerIdentity)"

# Test a log filter in Logs Explorer (output to stdout for quick count check)
gcloud logging read 'severity >= ERROR' --project=PROJECT_ID --limit=10

# Verify BigQuery IAM on the dataset
gcloud projects get-iam-policy PROJECT_ID --flatten="bindings[].members" \
  --format="table(bindings.role,bindings.members)" \
  --filter="bindings.members:gcp-sa-logging"

# Import an orphaned sink into Terraform state
tofu import google_logging_project_sink.main projects/PROJECT_ID/sinks/SINK_NAME
```
