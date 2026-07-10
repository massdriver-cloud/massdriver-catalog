# Changelog

All notable changes to the `aws-s3-static-site` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Real OpenTofu static website: S3 bucket with a globally-unique random-suffixed name, website configuration (index/error documents), public access block deliberately all-off, and a public-read bucket policy.
- Sample site in `src/site/` (index + 404 pages) so the bundle renders in a browser immediately after deploy — replace it with your build output to publish a real site.
- `fileset` upload loop with per-extension MIME types, content-hash `etag` (only changed files re-upload), and a `Cache-Control` header driven by `cache_max_age_seconds`.
- `application` artifact: bucket ARN as ID, live `http://` website endpoint URL, `/` health path.
- `params.examples`: Development (cache off for iteration) / Production (1-hour cache) presets.
- `$md.immutable` on `region`; friendly pattern validation on `index_document` / `error_document`.
- Checkov skips for the public-access checks (public by design — it's a website) plus replication, KMS (website endpoints can't serve KMS-encrypted objects), access logging, versioning, and event notifications.
- No alarms by design — S3 request metrics are opt-in and paid (see README).
