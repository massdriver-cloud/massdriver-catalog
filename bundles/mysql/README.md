# MySQL

A MySQL instance with sizing, HA, character set, and slow-query controls. Depends on a `virtual-network`.

> [!NOTE]
> This is a **placeholder bundle**. It ships with a complete schema and a stub `random_pet` IaC so you can poke at the developer experience on the Massdriver canvas before writing any real Terraform/OpenTofu. Once the shape feels right, swap the stub for your real database module.

## What it shows

This bundle is a worked example of the four things every bundle in the catalog brings together:

- **Self-service experience** — t-shirt sized instances (`xs` through `xl`), so nobody has to know what a `db.t4g.small` is. A version dropdown that labels 5.7 as end-of-life. An `$md.enum` subnet picker that fills itself in from the linked network. And a `username` capped at 32 characters, because that is MySQL's limit and the error you get for exceeding it is not obvious.
- **Operator guide** (`operator.md`) — a 2am runbook, templated so it shows this instance's live host, port, character set, and slow-query threshold.
- **Compliance** — `$md.immutable: true` on `username`, `database_name`, `db_version`, `character_set` and `collation`, all of which mean a rebuild rather than an edit. `$md.copyable: false` on `username`, so credentials do not follow a cloned environment. The password field on the `mysql-database` resource type carries `$md.sensitive: true`, so it is masked in the UI and its download is audit-logged. Three `massdriver_instance_alarm` definitions: `Storage 80% Full`, plus a `Slow Query Rate` that only exists when slow-query logging is on and a `Replication Lag` that only exists on HA instances.
- **IaC code** (`src/`) — a placeholder module that wires `params` and the upstream network `connection` into `massdriver_resource` outputs. Replace it with your real MySQL module (RDS, Cloud SQL, Azure Database, self-hosted, whatever you run).

## Customize it

1. Edit `massdriver.yaml` — match the params to your real MySQL module's inputs (engine version, parameter group, binlog settings, and so on). The [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) covers every key.
2. Rewrite `src/` to be your real Terraform/OpenTofu. `_massdriver_variables.tf` regenerates from your params and connections on every `mass bundle build`, so the schema and the variables stay in sync.
3. Update `operator.md` with your team's actual runbook — failover steps, slow-query investigation, restore-from-backup procedure.
4. Tune the alarm definitions in `src/alarms.tf` to thresholds your team will actually wake up for.
