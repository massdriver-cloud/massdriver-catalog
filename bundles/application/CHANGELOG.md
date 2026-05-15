# Changelog

All notable changes to the `application` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-14

### Added
- `app:` block lifting connection values into env vars (`DATABASE_HOST`, `DATABASE_URL`, `BUCKET_NAME`, etc.) and declaring required / optional secrets (`JWT_SECRET`, `SENTRY_DSN`, `GOOGLE_OAUTH_CLIENT_SECRET`).
- `params.examples`: Development / Staging / Production presets matching the param shape.
- `environment` enum (`development` / `staging` / `production`) and `log_level` enum (`debug` → `error`) with `oneOf` + `const` + `title` for human-readable labels.
- `cpu_limit` / `memory_limit` enums modeled on Kubernetes resource strings.
- `health_check_path` parameter, used in both the env-var contract and the emitted `application` resource.
- `image` regex + `message.pattern` requiring `image:tag` or `image@digest`.
- `domain_name` DNS-name pattern with `message.pattern`.
- UI tweaks: `ui:help` on `image` / `replicas` / `log_level`; `ui:widget: updown` on integer fields; `ui:placeholder` on the health-check path and image fields.
- 2am runbook: alarm response playbooks (pod restarts, 5xx, p95 latency), kubectl-based rollback / restart / scale recipes, env-var sanity check with the actual env-var → source mapping.
- Three `massdriver_instance_alarm` stand-ins (`Pod Restart Rate`, `5xx Error Rate`, `p95 Latency`) via provider `~> 1.4`.
- Emitted `application` resource now includes `service_url` and `health_check_url`.

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped from `~> 1.3` to `~> 1.4`.
- `massdriver_artifact` → `massdriver_resource` in `src/artifacts.tf`. `massdriver_artifact` is removed in provider v2.0.

### Removed
- `operator.md` placeholder sections — replaced with runbook-grade content.

## [0.0.0] — initial draft
- `image` / `replicas` / `port` / `domain_name` params, `database_policy` / `bucket_policy` via `$md.enum`, `network` / `database` / `bucket` connections, `random_pet`-based stub IaC, default-template operator runbook.
