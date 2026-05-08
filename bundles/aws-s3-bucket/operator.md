# AWS S3 Bucket Runbook

It's 2am. Uploads are failing. Here's what to check.

## Browser uploads return CORS errors

1. Confirm the failing origin is in `cors_origins`. Adding it requires a redeploy — the bucket-level CORS config is rebuilt on every apply.
2. The browser preflight must include `Origin`, `Access-Control-Request-Method`, and `Access-Control-Request-Headers`. If the client strips these, no S3 config will fix it.

## Presigned URLs return `403 SignatureDoesNotMatch`

- The clock on the signing host is skewed. AWS rejects signatures > 5 minutes off.
- The IAM identity that signed the URL doesn't have `s3:PutObject` on the bucket.
- The presigned URL expired. Default lifetime is `presigned_url_expiration_seconds`.

## Uploads succeed but the object is unreadable

If `encryption` is `sse-kms`, the consuming role needs `kms:Decrypt` on the bucket's KMS key (`bucket.kms_key_arn`). Bind that into the workload's role.

## Recovering a deleted object

If `versioning` is `enabled`, deletes are soft — the object becomes a delete marker. Remove the marker via:

```bash
aws s3api list-object-versions --bucket <bucket> --prefix <key>
aws s3api delete-object --bucket <bucket> --key <key> --version-id <delete-marker-id>
```

If `versioning` is `suspended`, only versions created while it was enabled survive.

## Storage bill is climbing

- Check `lifecycle_archive_after_days`. Moving cold UGC to Glacier IR cuts storage cost ~70% with sub-millisecond retrieval.
- Enable `enable_intelligent_tiering` if access patterns are unpredictable.
- Audit incomplete multipart uploads — they accrue storage cost forever. Lifecycle abort rules should be added if your traffic is bursty.

## Granting workloads access

Each workload gets its own IAM role. Bind one of the policies in `bucket.policies` (read/write/presign/admin) to that role. The example policies are starting points — tighten them to specific prefixes if you can.
