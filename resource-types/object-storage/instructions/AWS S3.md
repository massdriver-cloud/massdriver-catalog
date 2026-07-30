# Importing an existing S3 bucket

Use this when you already have an S3 bucket and want Massdriver to know about it, instead of provisioning a new one with the `aws-s3-bucket` bundle.

## Where to find each field

1. Open the **S3 console** → your bucket.
   - `name`: the bucket name.
   - `region`: shown in the bucket's **Properties** tab under "AWS Region".
   - `endpoint`: `https://<bucket-name>.s3.<region>.amazonaws.com`.
   - `id`: the bucket ARN, `arn:aws:s3:::<bucket-name>` (find it in **Properties** → "Amazon Resource Name (ARN)").
2. If server-side encryption is enabled with a customer-managed key: **Properties** → "Default encryption" → copy the KMS key ARN into `kms_key_arn`. Leave blank if using the AWS-managed key.
3. In the **IAM console**, find (or create) the managed policies you want consumers to be able to attach — one per access level you support (e.g. `read-only`, `read-write`).
   - `policies[].id`: each policy's ARN.
   - `policies[].name`: a short label shown in the app bundle's access-level dropdown.

## Notes

- This resource type represents private, application-owned storage. For public asset serving, put a CDN (CloudFront) in front of a bucket rather than making the bucket itself public.
