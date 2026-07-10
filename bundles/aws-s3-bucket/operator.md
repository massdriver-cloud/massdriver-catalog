---
templating: mustache
---

# S3 Bucket Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Bucket | `{{artifacts.bucket.bucket_name}}` |
| Region | `{{artifacts.bucket.region}}` |
| Access | `{{params.access}}` |
| Versioning | `{{params.versioning_enabled}}` |
| Object lock | `{{params.object_lock}}` |

---

## "We deleted something important"

If versioning is on (check the table above), the object isn't gone — S3 just placed a *delete marker* on top of it. Remove the marker and the previous version comes back.

```bash
# Find the object's versions and its delete marker
aws s3api list-object-versions --bucket {{artifacts.bucket.bucket_name}} \
  --prefix path/to/the-file \
  --query '{Versions: Versions[].{Key: Key, VersionId: VersionId, LastModified: LastModified}, DeleteMarkers: DeleteMarkers[].{Key: Key, VersionId: VersionId}}'

# Restore by deleting the delete marker (use the DeleteMarkers VersionId)
aws s3api delete-object --bucket {{artifacts.bucket.bucket_name}} \
  --key path/to/the-file --version-id THE_DELETE_MARKER_VERSION_ID
```

If the file was *overwritten* rather than deleted, copy the good version back on top:

```bash
aws s3api copy-object --bucket {{artifacts.bucket.bucket_name}} \
  --key path/to/the-file --version-id THE_GOOD_VERSION_ID \
  --copy-source "{{artifacts.bucket.bucket_name}}/path/to/the-file?versionId=THE_GOOD_VERSION_ID"
```

If versioning is off, the object is unrecoverable from S3 — go to your application-level backups. Then turn `versioning_enabled` on so this never happens again.

**Clock's ticking:** old versions are expired after `{{params.expire_noncurrent_versions_days}}` days (0 = never). Restore before then.

## "The bucket is public and it shouldn't be"

1. Check `params.access` in the table above. If it says `public_read`, someone chose that — change the parameter to `private` and redeploy. That flips all four public access blocks back on and removes the public bucket policy.
2. If the param already says `private` but something reports the bucket as public, verify what AWS actually has:

   ```bash
   aws s3api get-public-access-block --bucket {{artifacts.bucket.bucket_name}}
   aws s3api get-bucket-policy-status --bucket {{artifacts.bucket.bucket_name}}
   ```

   All four flags should be `true` and `IsPublic` should be `false`. If not, the bucket drifted outside of Massdriver — redeploy this instance to stomp the drift, then find out who changed it:

   ```bash
   aws cloudtrail lookup-events --lookup-attributes \
     AttributeKey=ResourceName,AttributeValue={{artifacts.bucket.bucket_name}} \
     --max-results 20
   ```

## "Costs are climbing"

On a versioned bucket the usual culprit is noncurrent versions piling up — every overwrite keeps the old copy.

```bash
# How much is current vs. old versions?
aws s3api list-object-versions --bucket {{artifacts.bucket.bucket_name}} \
  --query 'sum(Versions[?IsLatest==`false`].Size)' --output text   # bytes in old versions

aws s3 ls s3://{{artifacts.bucket.bucket_name}} --recursive --summarize | tail -2   # current size
```

Fixes, cheapest first:

1. Lower `expire_noncurrent_versions_days` (currently `{{params.expire_noncurrent_versions_days}}`; 0 means old versions are kept forever) and redeploy. The lifecycle rule cleans up from there.
2. Look for a workload rewriting the same keys in a loop — each rewrite mints a new version.
3. If object lock is on, versions inside the retention window (`{{params.object_lock_retention_days}}` days) cannot be deleted early — the spend rides out the window by design.
