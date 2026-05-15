# Changelog

All notable changes to the `postgres` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-14

### Added
- `params.examples`: Development / Staging / Production HA presets.
- `instance_size` (t-shirt size enum xs → xl) and `allocated_storage_gb` (multipleOf 10, 20–16384 GB).
- `backup_retention_days` (0–35) and `high_availability` boolean, with a `dependencies` block requiring `multi_az_zones` only when HA is on.
- `subnet_filter` parameter using `$md.enum` to populate a dropdown from the connected `network`'s subnets (`options: .subnets`, mirrors the `database_policy` / `bucket_policy` pattern on the application bundle).
- Human-readable PostgreSQL version selector built with `oneOf` + `const` + `title` (so `"12"` shows as "12 (out of community support — upgrade soon)").
- `message.pattern` override on `database_name` and `username`.
- Multi-annotation guardrails: `username` gets `$md.immutable: true` and `$md.copyable: false`; `database_name` and `db_version` are immutable.
- UI tweaks: `ui:help` on `db_version` / `allocated_storage_gb` / `backup_retention_days` / `high_availability`; `ui:widget: updown` on integers.
- 2am runbook: alarm response playbooks (high connections, storage 80%, replication lag), interpolated `psql` / `pg_dump` / `pg_restore` commands, failover steps.
- Three `massdriver_instance_alarm` stand-ins (`High Connections`, `Storage 80% Full`, and a conditional `Replication Lag` for HA deployments) via provider `~> 1.4`.

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped from `~> 1.3` to `~> 1.4`.
- `massdriver_artifact` → `massdriver_resource` in `src/artifacts.tf`. `massdriver_artifact` is removed in provider v2.0.
- The emitted resource now includes `high_availability` so consumers can branch on it.

### Removed
- `operator.md` placeholder sections (`Welcome / What to Include / Pro Tips`) — replaced with runbook-grade content.

## [0.0.0] — initial draft
- `db_version` / `database_name` / `username` params; `network` connection; `random_pet`-based stub IaC; default-template operator runbook.
