# Changelog

## 0.1.0 — 2026-05-14

### Added
- `app:` block lifting connection values into env vars (`DATABASE_HOST`, `DATABASE_URL`, `BUCKET_NAME`, etc.) and declaring required / optional secrets (`JWT_SECRET`, `SENTRY_DSN`, `GOOGLE_OAUTH_CLIENT_SECRET`).
- `params.examples`: Development / Staging / Production presets matching the param shape.
- `environment` enum (`development` / `staging` / `production`) and `log_level` enum (`debug` → `error`) with `oneOf` + `const` + `title` for human-readable labels.
- `cpu_limit` / `memory_limit` enums modeled on Kubernetes resource strings.
- `health_check_path` parameter, used in both the env-var contract and the emitted `application` resource.
- `image` pattern + `message.pattern` requiring `image:tag` or `image@digest`.
- `domain_name` DNS-name pattern with `message.pattern`.
- UI tweaks: `ui:help` on `image` / `replicas` / `log_level`; `ui:widget: updown` on integer fields; `ui:placeholder` on the health-check path and image fields.
- 2am runbook filed by symptom: crash-loop triage off `lastState.terminated.reason`, 5xx and p95 latency response, missing-connection diagnosis from the container's own environment, live restart / scale / rollback commands.
- Three `massdriver_instance_alarm` stand-ins (`Pod Restart Rate`, `5xx Error Rate`, `p95 Latency`).

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped to `~> 2.0`.
- `massdriver_artifact` → `massdriver_resource` in `src/resources.tf`. `massdriver_artifact` is removed in provider v2.0.
- Emitted `application` resource now includes `service_url` and `health_check_url`.

### Removed
- `operator.md` placeholder sections — replaced with runbook-grade content.

## 0.0.0 — initial draft
- `image` / `replicas` / `port` / `domain_name` params, `database_policy` / `bucket_policy` via `$md.enum`, `network` / `database` / `bucket` connections, `random_pet`-based stub IaC, default-template operator runbook.
