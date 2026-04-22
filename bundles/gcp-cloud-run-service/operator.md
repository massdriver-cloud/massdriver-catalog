---
templating: mustache
---

# GCP Cloud Run Service — Operator Runbook

## Non-obvious constraints

**Each bundle instance creates its own service account.** The SA email is derived from the bundle's `name_prefix`. If the package is renamed, the SA is destroyed and recreated. Any out-of-band IAM bindings referencing the old SA email (e.g., manually granted Artifact Registry reader) must be reapplied. Canvas-wired bindings (Pub/Sub, BigQuery, GCS) are recreated automatically on the next deploy.

**The push subscription uses a SEPARATE service account from the runtime SA.** When `incoming_topic` is connected, this bundle creates two SAs: the runtime SA (which the container runs as and which holds data-access IAM bindings) and a `push_invoker` SA (which Pub/Sub uses exclusively to OIDC-authenticate HTTP push deliveries). Do not confuse them — they have different emails, different roles, and different lifecycles. The push invoker SA is named `<name_prefix>-p` in GCP.

**The VPC connector must be in the same region as this Cloud Run service.** The connector region is taken from the `catalog-demo/gcp-vpc-connector` artifact (`connector.region`). If the connector is in a different region than the landing zone's `network.region`, the Cloud Run deploy will fail with a region mismatch error. Deploy the connector bundle in the correct region before wiring.

**`vpc_egress = PRIVATE_RANGES_ONLY` does NOT route all traffic through the VPC.** Only RFC1918 destinations (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) are routed through the connector. Public API calls (e.g., Google APIs, external HTTP endpoints) still egress directly to the internet. If your downstream endpoint — such as a Kafka broker — is on a private IP behind the connector, use `ALL_TRAFFIC` to force all egress through the VPC. If using `ALL_TRAFFIC`, ensure the VPC has a Cloud NAT gateway configured, otherwise internet-bound traffic will have no route.

**Push subscription ack deadline is capped at 600 seconds.** If a handler cannot complete within 600 seconds, it must acknowledge the message early (return HTTP 2xx immediately) and process asynchronously using a background task, Cloud Tasks, or another mechanism. Returning a non-2xx after the deadline causes Pub/Sub to redeliver the message, which leads to duplicate processing.

**New deployments route 100% of traffic to the latest revision immediately.** Blue/green splits must be configured before deploying the new revision. You cannot retroactively split traffic between revisions once the new one is live at 100%.

**Changing `ingress` triggers a new revision and a cold start.** Even if `min_instances > 0`, an ingress change forces revision replacement.

**`min_instances > 0` means continuous billing.** You pay for idle capacity at the full CPU+memory rate at all times.

**Container port must match what the image listens on.** A mismatch causes revision health check failure and Cloud Run rolls back. Error in logs: `Container failed to start. Failed to start and then listen on the port defined by the PORT environment variable.`

**The runtime SA does not have `roles/artifactregistry.reader` by default.** If a revision fails with `image not found` or `permission denied` at startup, grant the role:
```bash
gcloud artifacts repositories add-iam-policy-binding <REPO> \
  --location={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}} \
  --member="{{artifacts.cloud_run_service.runtime_service_account_member}}" \
  --role="roles/artifactregistry.reader"
```

**Canvas wire changes require a deploy to take effect.** Connecting or disconnecting a data artifact on the canvas does not grant or revoke IAM access. The Terraform apply must run to create or destroy the binding.

## Troubleshooting

**Revision fails to start (startup timeout).**
Default startup probe timeout is 240 seconds. Diagnose:
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="{{artifacts.cloud_run_service.service_name}}" AND (textPayload:"Container failed" OR textPayload:"failed to start")' \
  --project={{artifacts.cloud_run_service.project_id}} \
  --limit=20
```
Check for: missing environment variables, wrong port, failed startup connections. Test locally: `docker run -p 8080:<port> <image>` and confirm it starts quickly.

**5xx errors in production.**
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="{{artifacts.cloud_run_service.service_name}}" AND httpRequest.status>=500' \
  --project={{artifacts.cloud_run_service.project_id}} \
  --limit=50 \
  --format="table(timestamp,httpRequest.status,httpRequest.requestUrl)"
```

**Service can't access a connected resource (Pub/Sub, BigQuery, GCS).**
Confirm the canvas wire is connected AND the package has been deployed since the wire was added. Check the specific IAM binding:
```bash
# Pub/Sub
gcloud pubsub topics get-iam-policy <TOPIC_NAME> \
  --project={{artifacts.cloud_run_service.project_id}} \
  --format="table(bindings.role,bindings.members)"

# BigQuery
bq get-iam-policy {{artifacts.cloud_run_service.project_id}}:<DATASET_ID>

# GCS
gcloud storage buckets get-iam-policy gs://<BUCKET_NAME>
```
The member should be `{{artifacts.cloud_run_service.runtime_service_account_member}}`.

## Day-2 operations

**Rolling back to a prior revision:**
```bash
# List revisions to find the last known-good one
gcloud run revisions list \
  --service={{artifacts.cloud_run_service.service_name}} \
  --region={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}} \
  --format="table(name,status.conditions[0].status)"

# Shift 100% traffic to the prior revision
gcloud run services update-traffic {{artifacts.cloud_run_service.service_name}} \
  --region={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}} \
  --to-revisions=<REVISION_NAME>=100
```
This rollback is manual and temporary. The next Massdriver deploy overrides it. Fix the image or config, then redeploy.

**Pinning to a digest to prevent silent image changes:**
```bash
gcloud container images describe <IMAGE>:<TAG> \
  --format="value(image_summary.digest)"
# Use the output sha256:... in the image param: <IMAGE>@sha256:...
```

**Scaling changes:** Update `min_instances` or `max_instances` params and redeploy. In-place, safe.

## Useful commands

```bash
# Describe the service (traffic splits, SA, status)
gcloud run services describe {{artifacts.cloud_run_service.service_name}} \
  --region={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}} \
  --format="yaml(name,status,spec.template.spec.serviceAccountName,spec.traffic)"

# List revisions with status
gcloud run revisions list \
  --service={{artifacts.cloud_run_service.service_name}} \
  --region={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}} \
  --format="table(name,status.conditions[0].status,metadata.creationTimestamp)"

# Tail recent application logs
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="{{artifacts.cloud_run_service.service_name}}"' \
  --project={{artifacts.cloud_run_service.project_id}} \
  --limit=100 \
  --format=json | jq '.[].textPayload // .[].jsonPayload'

# Send a test request (authenticated)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  {{artifacts.cloud_run_service.service_url}}/healthz

# Check IAM on the service
gcloud run services get-iam-policy {{artifacts.cloud_run_service.service_name}} \
  --region={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}}

# Describe the runtime service account
gcloud iam service-accounts describe {{artifacts.cloud_run_service.runtime_service_account_email}} \
  --project={{artifacts.cloud_run_service.project_id}}
```
