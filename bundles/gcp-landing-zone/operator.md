---
templating: mustache
---

# GCP Landing Zone — Operator Runbook

## Non-obvious constraints

**Service account name is immutable.** Changing it destroys the existing SA and creates a new one. Any downstream IAM bindings referencing the old SA email break immediately. Treat the workload SA name as permanent after first deploy.

**Removing an API from `enabled_apis` does not disable it in GCP.** The `disable_on_destroy = false` flag means Terraform removes the state entry but never calls the GCP disable API. The API stays enabled. To actually disable it, run `gcloud services disable <api> --project={{artifacts.landing_zone.project_id}}` manually after confirming no resources depend on it.

**Budget requires Cloud Billing linked to the project.** If deploy fails with a billing budget error, confirm the project has a billing account attached in the GCP console before enabling the budget param.

**Budget alert emails require a verified notification channel.** The Google Cloud Monitoring email channel must be verified in GCP before alerts deliver. Billing admins on the account always receive alerts regardless of channel configuration.

**Newly added APIs can take 1–2 minutes to propagate.** If a downstream bundle deploy fails immediately after adding an API here, wait a minute and retry.

## Troubleshooting

**Downstream bundle fails with "API has not been used in project X."**
Add the required API to `enabled_apis` in this package, deploy, wait ~60 seconds, then retry the downstream bundle.

Common APIs for this data platform:
- `pubsub.googleapis.com` — required for gcp-pubsub-topic
- `bigquery.googleapis.com` — required for gcp-bigquery-dataset
- `run.googleapis.com` — required for gcp-cloud-run-service
- `storage.googleapis.com` — required for gcp-storage-bucket
- `billingbudgets.googleapis.com` — required when budget is enabled

To check which APIs are currently enabled:
```bash
gcloud services list --enabled --project={{artifacts.landing_zone.project_id}}
```

**Budget not enabled because billing API is missing.**
```bash
gcloud services list --enabled --project={{artifacts.landing_zone.project_id}} | grep billingbudgets
```
If nothing returns, add `billingbudgets.googleapis.com` to `enabled_apis` and redeploy before enabling the budget.

**Workload SA has unexpected project-level IAM bindings.**
The workload SA should have no project-level bindings after deploy — downstream bundles add per-resource bindings. If you see unexpected bindings:
```bash
gcloud projects get-iam-policy {{artifacts.landing_zone.project_id}} \
  --flatten="bindings[].members" \
  --filter="bindings.members:{{artifacts.landing_zone.workload_identity.service_account_email}}" \
  --format="table(bindings.role)"
```
An empty result is expected and correct.

**IAM binding changes outside Terraform get overwritten.**
Any bindings added manually (console or gcloud) will be removed on the next Massdriver deploy. Add permanent bindings via the bundle source.

## Day-2 operations

**Adding APIs after initial deploy:** Update `enabled_apis` in the package config and redeploy. Adding an API adds a new `google_project_service` resource without touching existing ones.

**Disabling an API:** Remove it from `enabled_apis` and redeploy. Terraform drops the state entry but does NOT call the GCP disable API. Manually disable via `gcloud services disable` if required.

**Changing budget amount or alert thresholds:** Update params and redeploy. The `google_billing_budget` resource updates in-place.

**Disabling the budget after it was enabled:** Set `budget.enabled = false` and redeploy. The budget and notification channel are destroyed. Spend is not affected — only alerting is removed.

**Rotating the deploy credential:** Update the GCP credential in the Massdriver UI under environment credential settings, then redeploy. Terraform state does not hold the credential — it is injected at plan time.

## Useful commands

```bash
# List enabled APIs in the project
gcloud services list --enabled --project={{artifacts.landing_zone.project_id}}

# Check IAM bindings for the workload service account
gcloud projects get-iam-policy {{artifacts.landing_zone.project_id}} \
  --flatten="bindings[].members" \
  --filter="bindings.members:{{artifacts.landing_zone.workload_identity.service_account_email}}" \
  --format="table(bindings.role)"

# Describe the workload service account
gcloud iam service-accounts describe {{artifacts.landing_zone.workload_identity.service_account_email}} \
  --project={{artifacts.landing_zone.project_id}}

# List all service accounts in the project
gcloud iam service-accounts list --project={{artifacts.landing_zone.project_id}}
```
