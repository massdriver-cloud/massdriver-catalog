---
templating: mustache
---

# Storage Bucket Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Bucket ID | `{{artifacts.bucket.id}}` |
| Deployed name | `{{artifacts.bucket.name}}` |
| Endpoint | `{{artifacts.bucket.endpoint}}` |
| Region | `{{artifacts.bucket.region}}` |
| Access level | `{{params.access_level}}` |
| Versioning | `{{params.versioning_enabled}}` |
| Object lock | `{{params.object_lock}}` (retention `{{params.object_lock_retention_days}}d`) |

---

## Active alarms — what they mean

### 5xx Error Rate

The bucket is returning server errors. Either the storage backend is degraded (check the cloud status page first) or your IAM policies are dropping requests in a way that surfaces as 5xx rather than 403.

```bash
# AWS — error breakdown over the last hour
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name 5xxErrors \
  --dimensions Name=BucketName,Value={{artifacts.bucket.name}} Name=FilterId,Value=EntireBucket \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) \
  --end-time $(date -u +%FT%TZ) \
  --period 60 --statistics Sum
```

```bash
# Look at the most recent access-log entries with non-2xx status
aws s3 ls s3://{{artifacts.bucket.name}}-access-logs/ | tail -5
aws s3 cp s3://{{artifacts.bucket.name}}-access-logs/<latest-key> - | grep -E ' "[0-9]+ 5[0-9]{2} '
```

### Anonymous Access Anomaly *(private buckets only)*

A request reached the bucket without authentication. On a private bucket this should be zero. Possible causes: a misconfigured CloudFront origin, a recently-pushed public bucket policy, or an actual probe / leak attempt.

```bash
# AWS — confirm the bucket really is locked down
aws s3api get-public-access-block --bucket {{artifacts.bucket.name}}
aws s3api get-bucket-policy-status --bucket {{artifacts.bucket.name}}
aws s3api get-bucket-acl --bucket {{artifacts.bucket.name}}
```

If any of those show public, page security and undo the public exposure before investigating root cause.

---

## Common operations

### List contents

```bash
# AWS
aws s3 ls s3://{{artifacts.bucket.name}}/ --recursive --human-readable --summarize | tail -5

# Azure
az storage blob list --container-name {{artifacts.bucket.name}} --output table

# GCS
gcloud storage ls --recursive gs://{{artifacts.bucket.name}}/
```

### Upload / sync

```bash
# AWS
aws s3 sync ./local-folder/ s3://{{artifacts.bucket.name}}/remote-folder/

# GCS
gcloud storage rsync -r ./local-folder/ gs://{{artifacts.bucket.name}}/remote-folder/
```

### Audit public access

```bash
# AWS
aws s3api get-bucket-policy --bucket {{artifacts.bucket.name}} | jq -r '.Policy' | jq
aws s3api get-public-access-block --bucket {{artifacts.bucket.name}}

# GCS
gcloud storage buckets get-iam-policy gs://{{artifacts.bucket.name}}
```

### Pre-signed URLs

```bash
# AWS — 15-minute URL
aws s3 presign s3://{{artifacts.bucket.name}}/path/to/object --expires-in 900

# GCS — 15-minute signed URL
gcloud storage sign-url gs://{{artifacts.bucket.name}}/path/to/object --duration=15m
```

### Versioning sanity check

{{#params.versioning_enabled}}
Versioning is **enabled**. Recover an overwritten object:

```bash
aws s3api list-object-versions --bucket {{artifacts.bucket.name}} --prefix path/to/object
aws s3api copy-object \
  --bucket {{artifacts.bucket.name}} \
  --copy-source "{{artifacts.bucket.name}}/path/to/object?versionId=<prior-version-id>" \
  --key path/to/object
```
{{/params.versioning_enabled}}
{{^params.versioning_enabled}}
Versioning is **disabled**. Accidental overwrites are unrecoverable. Enable versioning in this bundle's params and redeploy if you're storing anything that matters.
{{/params.versioning_enabled}}

---

## Object lock notes

{{#params.object_lock}}
Object lock is **on** with a `{{params.object_lock_retention_days}}d` retention. Objects in this bucket cannot be deleted or overwritten until their retention expires — **not even by an admin, not even via the cloud console**. Plan storage growth accordingly.
{{/params.object_lock}}
{{^params.object_lock}}
Object lock is **off**. Once enabled, it's one-way — the bundle marks it `$md.immutable`, so toggling it on means destroy-and-recreate.
{{/params.object_lock}}

---

## Disaster recovery

`bucket_name` and `object_lock` are **immutable**. To change either, you'll deploy a new bucket and migrate:

1. Inventory the source: `aws s3 ls s3://{{artifacts.bucket.name}}/ --recursive | wc -l`
2. Deploy a new bucket bundle instance.
3. Sync: `aws s3 sync s3://{{artifacts.bucket.name}}/ s3://<new-bucket>/`
4. Re-link consumers to the new bucket; verify.
5. Empty and delete the old bucket. **Object lock retention applies** — if you can't wait for it to expire, you can't delete the old bucket. Plan accordingly.

---

**Edit this runbook:** https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/bucket/operator.md
