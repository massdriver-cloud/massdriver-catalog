# Bucket

An object-storage bucket with access levels, versioning, lifecycle rules, CORS, and optional object lock. No upstream connections.

> [!NOTE]
> This is a **placeholder bundle**. It ships with a complete schema and a stub `random_pet` IaC so you can poke at the developer experience on the Massdriver canvas before writing any real Terraform/OpenTofu. Once the shape feels right, swap the stub for your real bucket module.

## What it shows

This bundle is a worked example of the four things every bundle in the catalog brings together:

- **Self-service experience** — `access_level` as a labelled `oneOf` (so "Public Read+Write — rarely safe" is spelled out in the dropdown, not hidden behind an enum value), a re-orderable `lifecycle_rules` array (max 8, unique items) with per-rule storage class, CORS-origin URL pattern validation, and a conditional block that requires `object_lock_retention_days` + `versioning_enabled` whenever object lock is turned on.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live bucket name, access level, versioning state, and active lifecycle rules. Open it from the instance's runbook tab in the UI.
- **Compliance** — `$md.immutable: true` on `object_lock` (a one-way switch you can never undo by accident), public-access defaults that nudge toward private, and two `massdriver_instance_alarm` definitions (`5xx Error Rate`, conditional `Anonymous Access Anomaly` that fires only on private buckets).
- **IaC code** (`src/`) — a placeholder Terraform/OpenTofu module that wires `params` into `massdriver_resource` outputs. Replace it with your real bucket module (S3, GCS, Azure Blob, MinIO, whatever you run).

## Customize it

1. Edit `massdriver.yaml` — match the params to your real bucket module's inputs (region, KMS keys, replication targets, etc.).
2. Rewrite `src/` to be your real Terraform/OpenTofu. `_massdriver_variables.tf` regenerates from your params + connections on every `mass bundle build`, so the schema and the variables stay in sync.
3. Update `operator.md` with your team's actual runbook — public-access incident response, lifecycle policy debugging, restore-from-versioning procedure.
4. Tune the alarm definitions in `src/alarms.tf` to thresholds your team will actually wake up for.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
