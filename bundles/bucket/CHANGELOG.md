# Changelog

## 0.1.0 — 2026-05-14

### Added
- `params.examples`: Private app data / Public website assets / Compliance archive presets.
- `access_level` selector built with `oneOf` + `const` + `title` (Private flagged as recommended, Public Read+Write flagged as rarely safe).
- `object_lock` boolean (`$md.immutable: true` — one-way switch) with an `object_lock_retention_days` setting, defaulting to the 7-year (2557d) compliance convention.
- `lifecycle_rules` array (max 8, unique) with per-rule `transition_after_days` + `storage_class` enum.
- `cors_allowed_origins` array (max 20) with origin pattern validation.
- `bucket_name` constraints: 3–63 chars, pattern + `message.pattern`, `$md.immutable: true`.
- UI tweaks: `ui:help` on `access_level` / `object_lock` / `cors_allowed_origins`; `ui:options.orderable/addable/removable` on `lifecycle_rules`.
- 2am runbook filed by symptom: 5xx errors, anonymous access on a private bucket, recovering an overwritten or deleted object, an object that will not delete under retention, short-lived pre-signed access, and the copy path for changing an immutable field.
- Two `massdriver_instance_alarm` stand-ins (`5xx Error Rate`, conditional `Anonymous Access Anomaly`).

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped to `~> 2.0`.
- `massdriver_artifact` → `massdriver_resource` in `src/resources.tf`. `massdriver_artifact` is removed in provider v2.0.
- Emitted resource now includes `region` so consumers can scope clients without a second lookup.

### Removed
- `operator.md` placeholder sections — replaced with runbook-grade content.

## 0.0.0 — initial draft
- `bucket_name` + `versioning_enabled` params, no connections, `random_pet`-based stub IaC, default-template operator runbook.
