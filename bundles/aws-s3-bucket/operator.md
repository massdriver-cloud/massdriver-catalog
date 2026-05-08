---
templating: mustache
---

# AWS S3 — Operator Runbook

- **Instance:** `{{id}}`
- **Bucket name:** {{#artifacts.bucket}}`{{artifacts.bucket.name}}`{{/artifacts.bucket}}

## List, upload, fetch

The bundle does not own a key prefix — that's the consuming workload's choice. The examples below use `uploads/` as a placeholder; substitute whatever prefix your workload writes under.

```bash
aws s3 ls s3://{{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}}/ \
  --region {{#artifacts.bucket}}{{artifacts.bucket.region}}{{/artifacts.bucket}}

aws s3 cp ./photo.jpg \
  s3://{{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}}/uploads/photo.jpg

aws s3 cp \
  s3://{{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}}/uploads/photo.jpg \
  ./photo.jpg
```

## Generate a presigned upload URL

```bash
aws s3 presign \
  --region {{#artifacts.bucket}}{{artifacts.bucket.region}}{{/artifacts.bucket}} \
  --expires-in {{params.presigned_url_expiration_seconds}} \
  s3://{{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}}/uploads/<key>
```

The browser must `PUT` to that URL with the same `Content-Type` it was signed against. Mismatched content types produce `SignatureDoesNotMatch`.

## Browser uploads return CORS errors

1. Confirm the failing origin is in the bundle's `cors_origins` param. Adding an origin requires a redeploy — bucket-level CORS is rebuilt on every apply.
2. The browser preflight must include `Origin`, `Access-Control-Request-Method`, and `Access-Control-Request-Headers`. If the client strips these, no S3 configuration will fix it.
3. Verify the live CORS rules:

```bash
aws s3api get-bucket-cors \
  --region {{#artifacts.bucket}}{{artifacts.bucket.region}}{{/artifacts.bucket}} \
  --bucket {{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}}
```

## SignatureDoesNotMatch on a presigned URL

- The signing host's clock is skewed. AWS rejects signatures more than five minutes off.
- The IAM identity that signed lacks `s3:PutObject` on the bucket prefix.
- The URL has expired (`presigned_url_expiration_seconds` is `{{params.presigned_url_expiration_seconds}}`).
- The `Content-Type` on the upload differs from the type signed.

## Recovering a deleted object

`versioning` is `{{params.versioning}}`. When `enabled`, deletes are soft and create a delete marker. Recovery removes the marker so the prior version becomes current again.

```bash
aws s3api list-object-versions \
  --region {{#artifacts.bucket}}{{artifacts.bucket.region}}{{/artifacts.bucket}} \
  --bucket {{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}} \
  --prefix <key>

aws s3api delete-object \
  --region {{#artifacts.bucket}}{{artifacts.bucket.region}}{{/artifacts.bucket}} \
  --bucket {{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}} \
  --key <key> \
  --version-id <delete-marker-id>
```

## Uploads succeed but reads return AccessDenied

When `encryption` is `sse-kms` (currently `{{params.encryption}}`), the consuming role needs `kms:Decrypt` on the bucket's KMS key in addition to S3 read permissions.

```bash
aws kms get-key-policy \
  --region {{#artifacts.bucket}}{{artifacts.bucket.region}}{{/artifacts.bucket}} \
  --key-id {{#artifacts.bucket}}{{artifacts.bucket.kms_key_arn}}{{/artifacts.bucket}} \
  --policy-name default
```

Add `kms:Decrypt` (and `kms:GenerateDataKey` for writers) on `{{#artifacts.bucket}}{{artifacts.bucket.kms_key_arn}}{{/artifacts.bucket}}` to the consuming role.

## Storage usage and cost

```bash
aws s3 ls s3://{{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}} \
  --recursive --human-readable --summarize | tail

# List incomplete multipart uploads (these accrue cost indefinitely)
aws s3api list-multipart-uploads \
  --region {{#artifacts.bucket}}{{artifacts.bucket.region}}{{/artifacts.bucket}} \
  --bucket {{#artifacts.bucket}}{{artifacts.bucket.name}}{{/artifacts.bucket}}
```

Tune `lifecycle_archive_after_days` (currently `{{params.lifecycle_archive_after_days}}`) to move cold objects to Glacier Instant Retrieval. Set `lifecycle_expire_after_days` to delete objects that no longer need retention.

## Granting workloads access

The bundle publishes pre-built IAM policies (Read / Write / Presign Upload / Admin) on the artifact's `policies` array. Bind the appropriate policy ARN to the workload's IAM role.

For browser-direct uploads, use the Presign Upload policy on the role that signs URLs. The browser itself does not need AWS credentials.

## Known constraints

- `bucket_name_prefix` is immutable. Renaming requires a new bucket and copy.
- `block_public_access` should remain `true` unless the bucket explicitly serves public content. Public-read on a UGC bucket leaks every uploaded object.
- Lifecycle rules apply asynchronously. Expect up to 24 hours between the rule firing and storage class changes appearing in inventory.
- Cross-region replication only replicates objects written after replication is configured. Backfill must be done manually with `aws s3 sync`.
