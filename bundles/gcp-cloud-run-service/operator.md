---
templating: mustache
---

# GCP Cloud Run Service — Operator Runbook

## Non-obvious constraints

**New deployments route 100% of traffic to the latest revision immediately.** Blue/green splits must be configured before deploying the new revision. You cannot retroactively split traffic between an old and new revision once the new one is live at 100%.

**Changing `ingress` triggers a new revision and a cold start.** Even if `min_instances > 0`, an ingress change forces revision replacement. Expect a brief cold start.

**`min_instances > 0` means continuous billing.** No scale-to-zero. You pay for idle capacity at the full CPU+memory rate at all times.

**Container port must match what the image listens on.** If the image doesn't listen on the configured port, the revision fails health checks and Cloud Run rolls back. Error in logs: `Container failed to start. Failed to start and then listen on the port defined by the PORT environment variable.` Check application logs before the platform logs.

**Image pull from Artifact Registry: the workload SA needs `roles/artifactregistry.reader`.** This bundle does not grant that role. If a revision fails with `image not found` or `permission denied` at startup, check this IAM binding first:
```bash
gcloud artifacts repositories get-iam-policy <REPO> \
  --location={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}}
```

**CPU-to-memory minimums are enforced at the API level.** 2 vCPU requires at least 512Mi; 4 vCPU requires at least 2Gi. A mismatched deploy fails before any revision is created.

**Connecting or disconnecting canvas wires requires a Massdriver deploy to take effect.** Wiring an artifact on the canvas does not grant IAM access. The Terraform apply must run to create or destroy the IAM binding.

## Troubleshooting

**Revision fails to start (startup timeout).**
Default startup probe timeout is 240 seconds. Diagnose:
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="{{artifacts.cloud_run_service.service_name}}" AND (textPayload:"Container failed" OR textPayload:"failed to start")' \
  --project={{artifacts.cloud_run_service.project_id}} \
  --limit=20
```
Check for: missing environment variables, failed DB connections, wrong port. Test locally: `docker run -p 8080:<port> <image>` and confirm it starts quickly.

**5xx errors in production.**
```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="{{artifacts.cloud_run_service.service_name}}" AND httpRequest.status>=500' \
  --project={{artifacts.cloud_run_service.project_id}} \
  --limit=50 \
  --format="table(timestamp,httpRequest.status,httpRequest.requestUrl)"
```

**IAM binding not applied after connecting a canvas wire.**
Connect the wire on the canvas AND redeploy this package. The binding does not exist until Terraform applies it.

**Image pull failure.**
Check the workload SA's Artifact Registry permission (see Non-obvious constraints above). Also confirm the image tag or digest exists in the registry.

## Day-2 operations

**Rolling back to a prior revision:**
```bash
# 1. List revisions to find the last known-good one
gcloud run revisions list \
  --service={{artifacts.cloud_run_service.service_name}} \
  --region={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}} \
  --format="table(name,status.conditions[0].status)"

# 2. Shift 100% traffic to the prior revision
gcloud run services update-traffic {{artifacts.cloud_run_service.service_name}} \
  --region={{artifacts.cloud_run_service.location}} \
  --project={{artifacts.cloud_run_service.project_id}} \
  --to-revisions=<REVISION_NAME>=100
```
This rollback is manual and temporary. The next Massdriver deploy will override it. Fix the image or config, then redeploy.

**Pinning to a digest to prevent silent image changes:**
```bash
gcloud container images describe <IMAGE>:<TAG> \
  --format="value(image_summary.digest)"
# Use the output sha256:... in the image param: <IMAGE>@sha256:...
```

**Scaling changes:** Update `min_instances` or `max_instances` params and redeploy. In-place safe.

**Rotating the runtime service account:** This requires a bundle code change (the SA is created by the landing zone). Changing the connected landing zone artifact and redeploying will update the SA reference.

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

# Check runtime SA's IAM bindings on a connected Pub/Sub topic
gcloud pubsub topics get-iam-policy <TOPIC_NAME> \
  --project={{artifacts.cloud_run_service.project_id}} \
  --format="table(bindings.role,bindings.members)"

# Check runtime SA's IAM bindings on a connected GCS bucket
gcloud storage buckets get-iam-policy gs://<BUCKET_NAME> \
  --format="table(bindings.role,bindings.members)"
```
