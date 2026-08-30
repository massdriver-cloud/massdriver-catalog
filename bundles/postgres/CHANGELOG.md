# Changelog

## 0.1.0 — 2026-05-14

### Added
- `params.examples`: Development / Staging / Production HA presets.
- `instance_size` (t-shirt size enum xs → xl) and `allocated_storage_gb` (multipleOf 10, 20–16384 GB).
- `backup_retention_days` (0–35) and `high_availability` boolean, with `multi_az_zones` for the number of zones replicas span.
- `subnet_filter` parameter using `$md.enum` to populate a dropdown from the connected `network`'s subnets (`options: .subnets`, mirrors the `database_policy` / `bucket_policy` pattern on the application bundle).
- Human-readable PostgreSQL version selector built with `oneOf` + `const` + `title` (so `"12"` shows as "12 (out of community support — upgrade soon)").
- `message.pattern` override on `database_name` and `username`.
- Multi-annotation guardrails: `username` gets `$md.immutable: true` and `$md.copyable: false`; `database_name` and `db_version` are immutable.
- UI tweaks: `ui:help` on `db_version` / `allocated_storage_gb` / `backup_retention_days` / `high_availability`; `ui:widget: updown` on integers.
- 2am runbook filed by symptom: connection storms, disk pressure, replication lag, manual failover, and the dump/restore path for changing an immutable field. Commands prompt for the password rather than rendering it into the page.
- Three `massdriver_instance_alarm` stand-ins (`High Connections`, `Storage 80% Full`, and a conditional `Replication Lag` for HA deployments).

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped to `~> 2.0`.
- `massdriver_artifact` → `massdriver_resource` in `src/resources.tf`. `massdriver_artifact` is removed in provider v2.0.
- The emitted resource now includes `high_availability` so consumers can branch on it.

### Removed
- `operator.md` placeholder sections (`Welcome / What to Include / Pro Tips`) — replaced with runbook-grade content.

## 0.0.0 — initial draft
- `db_version` / `database_name` / `username` params; `network` connection; `random_pet`-based stub IaC; default-template operator runbook.
