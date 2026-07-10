# AWS S3 Bucket

An S3 bucket that is private by default, encrypted at rest, versioned, and cleans up old object versions automatically. It emits **real IAM policies** on its artifact so application bundles can attach read or read/write access without writing any IAM themselves — that's the showcase.

## What it shows

- **Artifact-driven IAM** — the bundle creates two real `aws_iam_policy` resources (Read, Read/Write) and publishes their ARNs on the `object-storage` artifact's `policies` list. Consuming app bundles offer them as a dropdown (`$md.enum`) and attach the chosen one to their runtime role.
- **Self-service experience** — Development / Production presets, a `Private` / `Public Read` access selector with the warning in the label, an immutable one-way `object_lock` switch whose retention field only appears (and becomes required) when the lock is on.
- **Safe defaults** — all four public access blocks on, AES256 encryption, versioning on, noncurrent versions expired after 90 days so restore protection doesn't quietly become a storage bill.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live bucket name: restore a deleted object, verify the bucket isn't public, hunt down version-bloat costs.
- **IaC code** (`src/`) — real, minimal OpenTofu: bucket, versioning, encryption, public access block, conditional public-read policy, conditional GOVERNANCE-mode object lock, and a lifecycle rule.

## What it produces

An `object-storage` resource: bucket ARN, bucket name, region, and the policies list (`Read`, `Read/Write`) with real IAM policy ARNs in each entry's `id`.

## No alarms — on purpose

S3 request metrics (4xx/5xx rates) are an opt-in, paid CloudWatch feature, and the free storage metrics (`BucketSizeBytes`) report once a day — far too slow to alarm on. Rather than ship a misleading alarm, this bundle ships none; the operator guide covers cost investigation instead.

## Costs to know about

Effectively free at demo scale: S3 storage is ~$0.023/GB-month and the IAM policies are free. The only thing that grows unattended is noncurrent versions, which the default lifecycle rule expires after 90 days.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
