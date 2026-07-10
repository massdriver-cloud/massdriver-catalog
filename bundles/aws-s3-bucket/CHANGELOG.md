# Changelog

All notable changes to the `aws-s3-bucket` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Real OpenTofu S3 bucket: globally-unique random-suffixed name, AES256 encryption, versioning, public access block.
- `access` selector (`private` / `public_read`) that drives the public access block and a conditional public-read bucket policy.
- `$md.immutable` on `region` and on `object_lock` (a one-way switch — S3 object lock can only be enabled at creation).
- Conditional `dependencies` block: `object_lock_retention_days` required only when `object_lock` is on; GOVERNANCE-mode lock configuration in Terraform.
- Versioning forced on whenever object lock is enabled (lock requires it).
- Lifecycle rule expiring noncurrent versions after `expire_noncurrent_versions_days` (0 disables it).
- Two real IAM policies (`Read`, `Read/Write`) published on the `object-storage` artifact's `policies` list so app bundles can attach them.
- `params.examples`: Development / Production presets.
- No alarms by design — S3 request metrics are opt-in and paid; storage metrics are daily and too slow to alarm on (see README).
