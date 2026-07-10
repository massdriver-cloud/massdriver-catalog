# Changelog

All notable changes to the `k8s-wordpress` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Bitnami WordPress Helm chart (pinned `24.1.5`) deployed via the OpenTofu helm provider onto a linked `kubernetes-cluster`, backed by a linked `mysql-database` (chart's bundled MariaDB disabled).
- `app:` block: `app.envs` lifts database connection details into `WORDPRESS_DATABASE_*` env vars with JQ; `app.secrets` declares a **required** `WORDPRESS_ADMIN_PASSWORD` (blocks deploys until set) and an optional `WORDPRESS_SMTP_PASSWORD`.
- `database_policy` dropdown via `$md.enum` against the linked database's `policies`; the selection is annotated onto the Kubernetes namespace.
- Marketing Site / Development presets; `$md.immutable` + `$md.copyable: false` on `admin_username` with a friendly pattern message; `replicas` capped at 5 with ReadWriteMany guidance.
- `service_type` selector: `LoadBalancer` (public URL) or `ClusterIP` (internal only).
- Emits an `application` resource: `id` (`namespace/release`), `url` (only when the load balancer address is known), `health_path` `/wp-login.php`.
- Operator runbook: site down, white screen of death, admin lockout (wp-cli reset), database connection errors.
