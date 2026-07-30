# Changelog

All notable changes to the `aws-static-site` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Real Terraform/OpenTofu: private S3 origin bucket, CloudFront distribution with Origin Access Control (not the legacy OAI), a bucket policy scoped to that one distribution's ARN.
- Redirects and trailing-slash/index handling combined into a single CloudFront Function (`cloudfront-js-2.0` runtime), generated from the `redirects` param via `templatefile()`.
- A dedicated response headers policy (HSTS w/ preload, X-Content-Type-Options, X-Frame-Options: DENY, Referrer-Policy) applied to every response.
- `region` is its own param here (not derived from a network connection) — this bundle doesn't touch the cluster or the VPC; the only other bundle with its own region param is aws-vpc.
- `acm_certificate_arn` validated as a us-east-1 ARN — CloudFront requires the certificate there regardless of the site's own region.
- Custom error responses (403 and 404) both routed to `/404.html`.

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
