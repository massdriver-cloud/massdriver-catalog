---
templating: mustache
---

# GCP Vertex AI Workbench — Operator Runbook

## Non-obvious constraints

**Location is a zone, not a region.** This bundle appends `-a` to the landing zone region (e.g., `us-central1` → `us-central1-a`). GPU quota is zone-specific — if you get a quota error, check availability in the zone and request quota or change `local.zone` in `src/main.tf`.

**E2 machine types do not support GPUs.** If `accelerator_type` is set, the machine type must be N1 (`n1-standard-*`). Attempting to attach a GPU to an E2 machine fails at apply time.

**Machine type changes stop and restart the instance.** The instance shuts down, resizes, and restarts. Expect 5–10 minutes of downtime. Open notebooks are saved to disk and are available after restart.

**Shielded VM settings are hardcoded and not changeable in-place.** Changing `enable_secure_boot`, `enable_vtpm`, or `enable_integrity_monitoring` would require destroying and recreating the instance. These are always `true` and are not exposed as params.

**Idle shutdown requires the Workbench agent running.** The `idle-timeout-seconds` metadata key is only honoured if the Workbench agent is active. If the agent crashes or the instance was reimaged externally, idle shutdown will not fire.

**Per-instance SA recreates if the package is renamed.** The SA `account_id` is derived from `name_prefix`. Renaming destroys the old SA and creates a new one. Canvas-wired IAM bindings are recreated automatically on the next deploy. Out-of-band bindings must be reapplied manually.

**Canvas wires require a deploy to take effect.** Connecting or disconnecting the BigQuery dataset on the canvas does NOT grant or revoke IAM access immediately — a Massdriver deploy must run.

**`proxy_url` is empty until the instance is ACTIVE.** `{{artifacts.vertex_workbench.proxy_url}}` is only populated after the instance boots and the proxy registers. This takes 2–5 minutes after the Terraform apply completes.

## Troubleshooting

**Instance stuck in PROVISIONING or STARTING.**
Check the GCE instance serial console for boot errors:
```bash
gcloud compute instances get-serial-port-output {{artifacts.vertex_workbench.instance_name}} \
  --zone={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}}
```
Common causes: GPU quota exceeded, subnet CIDR exhausted, missing API enablement (`notebooks.googleapis.com`).

**`proxy_url` is empty after 10 minutes.**
```bash
gcloud workbench instances describe {{artifacts.vertex_workbench.instance_name}} \
  --location={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}} \
  --format="yaml(state,proxyUri,healthInfo)"
```
If `state` is ACTIVE but `proxyUri` is empty, the Workbench proxy failed to register. Stop and start the instance:
```bash
gcloud workbench instances stop {{artifacts.vertex_workbench.instance_name}} \
  --location={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}}

gcloud workbench instances start {{artifacts.vertex_workbench.instance_name}} \
  --location={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}}
```

**Notebook can't query BigQuery — Access Denied.**
Confirm the canvas wire is connected AND the package has been redeployed since the wire was added. Verify the IAM binding exists:
```bash
bq get-iam-policy {{artifacts.vertex_workbench.project_id}}:<BQ_DATASET_ID> \
  --format=prettyjson | grep -A3 "dataViewer"
```
The member should be `{{artifacts.vertex_workbench.instance_service_account_member}}`.

**GPU not available in zone.**
```bash
gcloud compute accelerator-types list \
  --filter="zone:{{artifacts.vertex_workbench.location}}" \
  --project={{artifacts.vertex_workbench.project_id}}
```
If the GPU type is absent, request quota for a different zone, then update `local.zone` in `src/main.tf` and redeploy.

**Instance not shutting down after idle timeout.**
Confirm the `idle-timeout-seconds` metadata key was set:
```bash
gcloud compute instances describe {{artifacts.vertex_workbench.instance_name}} \
  --zone={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}} \
  --format="yaml(metadata.items)"
```
If missing, the `idle_shutdown_timeout_minutes` param was 0 (disabled). The metadata key is only written when the value is > 0.

## Day-2 operations

**Stopping and starting the instance (e.g., to save costs overnight):**
```bash
# Stop
gcloud workbench instances stop {{artifacts.vertex_workbench.instance_name}} \
  --location={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}}

# Start
gcloud workbench instances start {{artifacts.vertex_workbench.instance_name}} \
  --location={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}}
```
Starting after an idle shutdown or manual stop takes 2–5 minutes. The proxy URL remains the same.

**Resizing the instance:** Update `machine_type` or `boot_disk_size_gb` params and redeploy. The instance stops, resizes, and restarts. Disk size can only be increased, not decreased.

**Adding a GPU after initial deploy:** Change `machine_type` to an N1 type, set `accelerator_type` and `accelerator_count`, and redeploy. This recreates the underlying GCE VM.

**Granting a user access to the JupyterLab UI:**
```bash
gcloud workbench instances add-iam-policy-binding {{artifacts.vertex_workbench.instance_name}} \
  --location={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}} \
  --role="roles/notebooks.viewer" \
  --member="user:alice@example.com"
```

## Useful commands

```bash
# Describe instance state and proxy URL
gcloud workbench instances describe {{artifacts.vertex_workbench.instance_name}} \
  --location={{artifacts.vertex_workbench.location}} \
  --project={{artifacts.vertex_workbench.project_id}} \
  --format="yaml(state,proxyUri,healthInfo,gceSetup.machineType,gceSetup.serviceAccounts)"

# List all Workbench instances in the project
gcloud workbench instances list \
  --location=- \
  --project={{artifacts.vertex_workbench.project_id}} \
  --format="table(name,location,state,proxyUri)"

# Describe the instance service account
gcloud iam service-accounts describe {{artifacts.vertex_workbench.instance_service_account_email}} \
  --project={{artifacts.vertex_workbench.project_id}}

# Check IAM bindings granted to the instance SA
gcloud projects get-iam-policy {{artifacts.vertex_workbench.project_id}} \
  --flatten="bindings[].members" \
  --filter="bindings.members:{{artifacts.vertex_workbench.instance_service_account_member}}" \
  --format="table(bindings.role)"

# Check runtime logs from the Workbench agent
gcloud logging read \
  'resource.type="gce_instance" AND labels."compute.googleapis.com/resource_name"="{{artifacts.vertex_workbench.instance_name}}"' \
  --project={{artifacts.vertex_workbench.project_id}} \
  --limit=50 \
  --format="table(timestamp,textPayload)"

# Check GCP Audit Logs for BigQuery access by the instance SA
gcloud logging read \
  'protoPayload.authenticationInfo.principalEmail="{{artifacts.vertex_workbench.instance_service_account_email}}" AND protoPayload.serviceName="bigquery.googleapis.com"' \
  --project={{artifacts.vertex_workbench.project_id}} \
  --limit=20 \
  --format="table(timestamp,protoPayload.methodName,protoPayload.resourceName)"
```
