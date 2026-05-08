---
templating: mustache
---

# GCP Storage Bucket — Operator Runbook

## Non-obvious constraints

**Bucket name is globally unique and immutable.** The name is derived from the Massdriver name prefix. Renaming requires decommissioning and recreating the package, then migrating all objects.

**Location is immutable.** Bucket location cannot be changed after creation. To move: copy all objects to a new bucket in the target location, update consumers, then decommission this package. Use `gcloud storage cp -r` or a Dataflow job for large datasets.

**Public access prevention is hardcoded.** `public_access_prevention = "enforced"` cannot be overridden through bundle configuration. Any attempt to grant `allUsers` or `allAuthenticatedUsers` via IAM is rejected by GCP even if the IAM call appears to succeed.

**Uniform bucket-level access is enabled.** Object-level ACLs are disabled. All access is IAM-only. Granting access to specific objects via ACLs is not possible.

**This bundle creates no IAM bindings.** Consumer bundles bind their own service accounts to this bucket. If a service can't read or write objects, the IAM binding is missing from the consumer bundle — not from here.

**Turning versioning off does not delete existing non-current versions.** GCS stops creating new versions, but existing non-current versions are retained and continue to incur storage charges. Add a lifecycle rule targeting `with_state: ARCHIVED` to clean them up.

**Lifecycle rules evaluate once daily, not in real time.** A rule set to delete objects after 30 days may not take effect until the next evaluation window.

**`Delete` action on a versioned bucket sets a delete marker — it does not immediately remove storage.** Add a second lifecycle rule targeting `with_state: ARCHIVED` with a shorter `age_days` to purge non-current versions and reclaim storage.

## Troubleshooting

**Permission denied on object read/write.**
Uniform bucket-level access is on — check bucket IAM, not object ACLs:
```bash
gcloud storage buckets get-iam-policy {{artifacts.storage_bucket.bucket_url}}
```
The workload SA needs `roles/storage.objectUser` to read and write, or `roles/storage.objectViewer` for read-only. If the binding is absent, redeploy the consumer bundle with the bucket wired on the canvas.

**Objects not being deleted by lifecycle rules.**
Lifecycle rules evaluate once daily. Wait up to 24 hours after a rule change. Inspect current lifecycle config:
```bash
gcloud storage buckets describe {{artifacts.storage_bucket.bucket_url}} \
  --format="yaml(lifecycle)"
```

**Storage costs unexpectedly high after disabling versioning.**
Old non-current versions are still present. List them:
```bash
gcloud storage ls -a {{artifacts.storage_bucket.bucket_url}}
```
Add a lifecycle rule with `with_state: ARCHIVED` to purge them.

**Deploy fails with "storage.googleapis.com has not been used in project."**
Add `storage.googleapis.com` to `enabled_apis` in the `gcp-landing-zone` package, redeploy, wait ~60 seconds, then retry.

## Day-2 operations

**Changing storage class:** Update `storage_class` param and redeploy. The bucket updates in-place. Existing objects retain their current storage class — only new writes use the new class. Use a lifecycle `SetStorageClass` rule to migrate existing objects.

**Enabling versioning:** Safe in-place change. Objects written before versioning was enabled have a single version. Objects overwritten or deleted afterward accumulate versions.

**Disabling versioning:** In-place change, but existing non-current versions are retained. Add a lifecycle rule targeting `with_state: ARCHIVED` to clean up.

**Granting access to another service account** (outside Terraform — will be overwritten on next apply):
```bash
gcloud storage buckets add-iam-policy-binding {{artifacts.storage_bucket.bucket_url}} \
  --member="serviceAccount:<sa-email>" \
  --role="roles/storage.objectViewer"
```
For permanent bindings, add a `google_storage_bucket_iam_member` resource to the consumer bundle source.

**Migrating objects to a new bucket:**
```bash
gcloud storage cp -r {{artifacts.storage_bucket.bucket_url}}/* gs://<new-bucket-name>/
```

## Useful commands

```bash
# List objects in the bucket
gcloud storage ls {{artifacts.storage_bucket.bucket_url}}

# List all objects including non-current versions
gcloud storage ls -a {{artifacts.storage_bucket.bucket_url}}

# Check bucket IAM policy
gcloud storage buckets get-iam-policy {{artifacts.storage_bucket.bucket_url}}

# Inspect lifecycle rules
gcloud storage buckets describe {{artifacts.storage_bucket.bucket_url}} \
  --format="yaml(lifecycle)"

# Copy a local file into the bucket
gcloud storage cp ./myfile.txt {{artifacts.storage_bucket.bucket_url}}/myfile.txt

# Sync a local directory to the bucket
gcloud storage rsync ./local-dir {{artifacts.storage_bucket.bucket_url}}/remote-dir --recursive
```
