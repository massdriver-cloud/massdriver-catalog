# Changelog

All notable changes to the `aws-s3-bucket` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Real Terraform/OpenTofu: S3 bucket, dedicated SSE-KMS key with rotation, versioning toggle, and an unconditional (non-configurable) public access block.
- Two IAM policies (`read-only`, `read-write`) scoped to the bucket + its KMS key, exposed via `policies[]` for IRSA attachment.
- `force_destroy` param, off by default — a dev/test bucket can opt in to easy teardown; production buckets shouldn't.
- Emits `object-storage`: id (ARN), name, endpoint, region, kms_key_arn, policies.

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
