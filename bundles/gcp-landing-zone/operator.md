---
templating: mustache
---

# GCP Landing Zone — Operator Runbook

## Non-obvious constraints

**This bundle manages project-level IAM for humans and groups, not workload service accounts.** Consumer bundles (Cloud Run, Vertex Workbench) own their own runtime SAs. Do not add workload SAs here.

**IAM bindings are additive and only removed when explicitly deleted from params.** `google_project_iam_member` does not reconcile the full project IAM policy. Removing a binding from params and redeploying destroys only that specific binding resource — all other project-level bindings remain untouched.

**Org policies are project-scoped, not org-wide.** `google_project_organization_policy` applies constraints at the project level only. Org-wide enforcement requires setting the policy at the org node, which is out of scope for this bundle.

**Removing an API from `enabled_apis` does not disable it in GCP.** `disable_on_destroy = false` means Terraform removes the state entry but never calls the GCP disable API. The API stays enabled. To actually disable it, run `gcloud services disable` manually after confirming no resources depend on it.

**Budget requires Cloud Billing linked to the project.** If deploy fails with a billing budget error, confirm the project has a billing account attached in the GCP console before enabling the budget param.

**Budget alert emails require a verified notification channel.** The Google Cloud Monitoring email channel must be verified in GCP before alerts deliver. Billing admins on the account always receive alerts regardless of channel configuration.

**Newly added APIs can take 1–2 minutes to propagate.** If a downstream bundle deploy fails immediately after adding an API here, wait ~60 seconds and retry.

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

**Org policy apply fails with "403 PERMISSION_DENIED".**
The deploy credential needs `orgpolicy.policy.set` at the project level:
```bash
gcloud projects add-iam-policy-binding {{artifacts.landing_zone.project_id}} \
  --member="serviceAccount:<deploy-sa-email>" \
  --role="roles/orgpolicy.policyAdmin"
```

**An IAM binding appears in GCP but is not in params.**
If the binding was added outside Terraform, it will not be touched by Massdriver. To remove it, use `gcloud` or the Console.

## Day-2 operations

**Adding a human operator binding:** Add `{role, member}` to `iam_bindings` and redeploy. Additive — no existing bindings are touched.

**Removing a human operator binding:** Remove the entry from `iam_bindings` and redeploy. Only that specific binding resource is destroyed.

**Adding an org policy constraint:** Add `{constraint, enforced}` to `org_policies` and redeploy.

**Removing an org policy constraint:** Remove the entry from `org_policies` and redeploy. The org's inherited policy (if any) applies after removal.

**Adding APIs after initial deploy:** Update `enabled_apis` and redeploy. Existing APIs are not touched.

**Disabling an API:** Remove it from `enabled_apis` and redeploy. Terraform drops the state entry but does NOT call the GCP disable API. Manually disable via `gcloud services disable` if needed.

**Changing budget amount or alert thresholds:** Update params and redeploy. The `google_billing_budget` resource updates in-place.

**Disabling the budget after it was enabled:** Set `budget.enabled = false` and redeploy. The budget and notification channel are destroyed.

**Rotating the deploy credential:** Update the GCP credential in the Massdriver UI under environment credential settings, then redeploy.

## Useful commands

```bash
# List enabled APIs in the project
gcloud services list --enabled --project={{artifacts.landing_zone.project_id}}

# Check all project-level IAM bindings
gcloud projects get-iam-policy {{artifacts.landing_zone.project_id}} \
  --format="table(bindings.role,bindings.members)"

# List active org policy constraints on the project
gcloud resource-manager org-policies list \
  --project={{artifacts.landing_zone.project_id}}

# Describe a specific org policy constraint
gcloud resource-manager org-policies describe constraints/iam.disableServiceAccountKeyCreation \
  --project={{artifacts.landing_zone.project_id}}

# List all service accounts in the project (workload SAs are owned by consumer bundles)
gcloud iam service-accounts list --project={{artifacts.landing_zone.project_id}}

# Manually disable an API (only needed if you removed it from enabled_apis and want it actually off)
gcloud services disable <api>.googleapis.com \
  --project={{artifacts.landing_zone.project_id}}
```
