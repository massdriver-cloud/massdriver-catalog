# Changelog

## 0.1.0 — 2026-05-14

### Added
- `params.examples`: Development / Staging / Production HA presets.
- `instance_size` (t-shirt size enum xs → xl) and `allocated_storage_gb` (multipleOf 10, 20–16384 GB).
- `character_set` and `collation` enums, both `$md.immutable: true`.
- `slow_query_log_enabled` with a `slow_query_log_long_query_time_seconds` threshold (1–60s).
- `high_availability` boolean with `multi_az_zones` for the number of zones replicas span.
- `subnet_filter` parameter using `$md.enum` to populate a dropdown from the connected `network`'s subnets (`options: .subnets`, mirrors the `database_policy` / `bucket_policy` pattern on the application bundle).
- Human-readable MySQL version selector built with `oneOf` + `const` + `title` (5.7 is marked end-of-life, 8.4 marked next-LTS).
- `message.pattern` override on `database_name` and `username`; `username` capped at 32 chars (MySQL limit).
- Multi-annotation guardrails: `username` gets `$md.immutable: true` and `$md.copyable: false`; `database_name`, `db_version`, `character_set`, `collation` are immutable.
- UI tweaks: `ui:help` on `db_version` / `backup_retention_days` / `high_availability`; `ui:widget: updown` on integers.
- 2am runbook filed by symptom: slow queries, replication lag, disk pressure, a stuck query blocking everything behind it, and the dump/restore path for changing an immutable field. Commands prompt for the password rather than rendering it into the page.
- Three `massdriver_instance_alarm` stand-ins (conditional `Slow Query Rate`, conditional `Replication Lag`, `Storage 80% Full`).

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped to `~> 2.0`.
- `massdriver_artifact` → `massdriver_resource` in `src/resources.tf`. `massdriver_artifact` is removed in provider v2.0.
- Emitted resource now includes `character_set` and `high_availability` so consumers can branch on them.

### Removed
- `operator.md` placeholder sections — replaced with runbook-grade content.

## 0.0.0 — initial draft
- `db_version` / `database_name` / `username` params; `network` connection; `random_pet`-based stub IaC; default-template operator runbook.
