# aws-s3-bucket

Stands up an Amazon S3 bucket tuned for user-generated content: browser uploads via presigned URLs, CORS, lifecycle archive/expire, server-side encryption, and presign-friendly IAM policies.

## What it provisions

- S3 bucket with a globally unique name (configured prefix + random suffix)
- Server-side encryption: SSE-S3 (AES-256) or SSE-KMS with a customer-managed key
- Versioning (`enabled` or `suspended`)
- CORS rules tied to the configured origins and max upload size
- Block Public Access (all four toggles) when enabled
- Object Ownership: `bucket-owner-enforced` (ACLs disabled) or `bucket-owner-preferred`
- Lifecycle rules for Glacier IR archival and/or expiration when configured
- Optional Intelligent Tiering, optional access logs to a sibling bucket
- Optional SNS event notifications on object-created
- Optional cross-region replication to a destination bucket ARN
- Bindable IAM policies (read, write, presign upload) for downstream IRSA bindings

## Connections

- `aws_authentication: aws-iam-role` — env-default, supplies the provisioning role

## Outputs

- `bucket: aws-s3-bucket` — bucket name, ARN, region, and a set of bindable IAM policies. Downstream apps bind one of those policies via IRSA to read/write or generate presigned upload URLs.

## Configuration highlights

- **`bucket_name_prefix`** — Bucket name prefix; a random suffix is appended for global uniqueness. Marked immutable; bucket names cannot be renamed.
- **`cors_origins`** — Origins permitted to upload via browser PUT/POST. Use exact origins in production, not wildcards.
- **`versioning`** — `enabled` protects against overwrites and deletes. Once enabled, can only be `suspended`, never disabled.
- **`object_ownership`** — `bucket-owner-enforced` disables ACLs entirely (recommended). Marked immutable.
- **`block_public_access`** — Enforces all four S3 BPA settings. Should be `true` unless serving content directly.
- **`lifecycle_archive_after_days`** / **`lifecycle_expire_after_days`** — Move to Glacier IR / permanently delete after N days. `0` disables.

See `massdriver.yaml` for the full param surface.

## Compliance

No skip list — Checkov runs clean by default for this bundle. Production environments (`md-target` matching `^(prod|prd|production)$`) hard-fail on Checkov findings; lower environments surface findings as warnings.

## Operator runbook

See [`operator.md`](./operator.md) for `aws s3` operations and troubleshooting.
