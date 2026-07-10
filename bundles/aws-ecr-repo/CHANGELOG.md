# Changelog

All notable changes to the `aws-ecr-repo` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Real OpenTofu ECR repository with AES256 encryption and scan-on-push.
- `image_tag_mutability` selector defaulting to `IMMUTABLE`, with the prod risk of `MUTABLE` spelled out in the option label.
- Lifecycle policy that keeps only the last `keep_last_images` images (1–500, default 20).
- `params.examples`: Development / Production presets.
- `$md.immutable` on `region` and `repository_name`; `message.pattern` override on `repository_name`.
- Emits a `container-registry` resource: ARN, registry host, repository URL, name, and region.
- Operator runbook covering rejected pushes on immutable tags, critical scan findings, and cluster pull failures.
