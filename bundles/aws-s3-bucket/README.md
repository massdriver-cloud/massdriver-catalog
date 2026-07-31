# Object Storage

Provisions a private S3 bucket for application file storage: uploads, generated reports, backups. Emits an `object-storage` resource with the bucket details and its access policies.

## What it provisions

- A bucket with public access blocked at the account-policy level. This is not parameter-configurable.
- Server-side encryption with a dedicated KMS key rather than the shared AWS default key, so decryption access can be scoped and audited per bucket.
- Two IAM access policies, read-only and read-write, that consuming apps attach through their service account's IAM role (IRSA). No static access keys are issued.
- Optional object versioning, so overwrites and deletes are recoverable.

## What this bucket is not for

Serving files directly to the public internet. For public assets, put a CDN in front of a bucket instead of opening the bucket itself; the `aws-static-site` bundle implements that pattern.

## Parameters worth knowing

- `bucket_name` is immutable, and S3 bucket names are globally unique across all of AWS.
- `force_destroy` allows the bucket to be destroyed while it still contains objects. When off, the bucket must be emptied manually before deletion.
- Versioning adds storage cost proportional to object churn.

## Operational notes

- `src/main.tf` provisions the bucket, KMS key, and IAM policies.
- Additional access levels (for example, a delete-only policy for a cleanup job) can be added in `massdriver.yaml` and `src/main.tf`.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
