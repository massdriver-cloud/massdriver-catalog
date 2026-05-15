# Changelog

All notable changes to the `bucket` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-14

### Added
- `params.examples`: Private app data / Public website assets / Compliance archive presets.
- `access_level` selector built with `oneOf` + `const` + `title` (Private flagged as recommended, Public Read+Write flagged as rarely safe).
- `object_lock` boolean (`$md.immutable: true` — one-way switch) with a `dependencies` block requiring `object_lock_retention_days` and `versioning_enabled` when on.
- `lifecycle_rules` array (max 8, unique) with per-rule `transition_after_days` + `storage_class` enum.
- `cors_allowed_origins` array (max 20) with origin pattern validation.
- `bucket_name` constraints: 3–63 chars, pattern + `message.pattern`, `$md.immutable: true`.
- UI tweaks: `ui:help` on `access_level` / `object_lock` / `cors_allowed_origins`; `ui:options.orderable/addable/removable` on `lifecycle_rules`.
- 2am runbook: alarm response playbooks (5xx, anonymous-access anomaly), pre-signed URLs, public-access audit commands across AWS / Azure / GCS, version-recovery and bucket-migration playbooks.
- Two `massdriver_instance_alarm` stand-ins (`5xx Error Rate`, conditional `Anonymous Access Anomaly`) via provider `~> 1.4`.

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped from `~> 1.3` to `~> 1.4`.
- `massdriver_artifact` → `massdriver_resource` in `src/artifacts.tf`. `massdriver_artifact` is removed in provider v2.0.
- Emitted resource now includes `region` so consumers can scope clients without a second lookup.

### Removed
- `operator.md` placeholder sections — replaced with runbook-grade content.

## [0.0.0] — initial draft
- `bucket_name` + `versioning_enabled` params, no connections, `random_pet`-based stub IaC, default-template operator runbook.
