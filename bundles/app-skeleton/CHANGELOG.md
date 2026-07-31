# Changelog

All notable changes to the `app-skeleton` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Generated from `templates/aws-eks-app`, with all six connections (aws_authentication, cluster, database, storage, queue, cache, email) required rather than optional — this bundle exists specifically to exercise every data-service resource type end to end.
- One example CronJob to prove the scheduled-work path alongside the Deployment/Service/Ingress path.
- No application logic — placeholder image, no business behavior. Real per-app bundles should be generated fresh from the template, not forked from this one.

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
