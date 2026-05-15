# MySQL

A MySQL instance with sizing, HA, character set, and slow-query controls. Depends on a `network`.

> [!NOTE]
> This is a **placeholder bundle**. It ships with a complete schema and a stub `random_pet` IaC so you can poke at the developer experience on the Massdriver canvas before writing any real Terraform/OpenTofu. Once the shape feels right, swap the stub for your real database module.

## What it shows

This bundle is a worked example of the four things every bundle in the catalog brings together:

- **Self-service experience** — t-shirt sized instances (`xs` → `xl`), an `$md.enum` subnet picker populated from the linked network, immutable `character_set` / `collation` dropdowns, a 32-char-capped `username` (MySQL's limit), and a conditional `slow_query_log_long_query_time_seconds` that appears only when slow query logging is on.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live host, port, character set, and slow-query settings. Open it from the instance's runbook tab in the UI.
- **Compliance** — immutability on `username` / `character_set` / `collation`, `$md.copyable: false` so credentials don't carry into cloned environments, `$md.sensitive: true` on the password output (masked in the UI and audit-logged on download), and three `massdriver_instance_alarm` definitions (`Storage 80% Full`, conditional `Slow Query Rate`, conditional `Replication Lag`).
- **IaC code** (`src/`) — a placeholder Terraform/OpenTofu module that wires `params` and the upstream network `connection` into `massdriver_resource` outputs. Replace it with your real MySQL module (RDS, Cloud SQL, Azure Database, self-hosted, whatever you run).

## Customize it

1. Edit `massdriver.yaml` — match the params to your real MySQL module's inputs (engine version, parameter group, binlog settings, etc.).
2. Rewrite `src/` to be your real Terraform/OpenTofu. `_massdriver_variables.tf` regenerates from your params + connections on every `mass bundle build`, so the schema and the variables stay in sync.
3. Update `operator.md` with your team's actual runbook — failover steps, slow-query investigation, restore-from-backup procedure.
4. Tune the alarm definitions in `src/alarms.tf` to thresholds your team will actually wake up for.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
