# Changelog

All notable changes to the `aws-ses-email` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Real Terraform/OpenTofu: SES domain identity + DKIM, a configuration set, and a dedicated IAM user with a send-only policy scoped to the domain identity's ARN.
- SMTP credentials chosen over the native SES send API for portability — same integration works against any other SMTP provider.
- SMTP password derived from the IAM secret key via AWS's documented HMAC-SHA256 chain (`src/scripts/ses_smtp_password.py`, invoked through the `external` provider) since no Terraform-native function computes it.
- Emits `email-credentials`: domain, region, configuration_set, smtp (host/port/username/password).

### Known trade-offs (flagged, not hidden)
- Domain verification is a manual DNS step after deploy — this bundle can't own your DNS zone for you. See operator.md.

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
