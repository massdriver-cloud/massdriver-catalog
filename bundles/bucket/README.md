# Bucket

An object-storage bucket with access levels, versioning, lifecycle rules, CORS, and optional object lock. No upstream connections.

> [!NOTE]
> This is a **placeholder bundle**. It ships with a complete schema and a stub `random_pet` IaC so you can poke at the developer experience on the Massdriver canvas before writing any real Terraform/OpenTofu. Once the shape feels right, swap the stub for your real bucket module.

## What it shows

This bundle is a worked example of the four things every bundle in the catalog brings together:

- **Self-service experience** — `access_level` is a labelled `oneOf`, so the dropdown reads "Public Read+Write — anonymous PUT allowed (rarely safe)" instead of hiding that behind an enum value. `lifecycle_rules` is a re-orderable array (max 8, no duplicates) where each rule picks its own storage class. `cors_allowed_origins` validates that each entry is a real origin.
- **Operator guide** (`operator.md`) — a 2am runbook, templated so it shows this bucket's live name, access level, versioning state, and object-lock retention.
- **Compliance** — `$md.immutable: true` on `object_lock`, a one-way switch nobody can undo by accident, and on `bucket_name`, which no cloud provider lets you rename. Access defaults nudge toward private. Two `massdriver_instance_alarm` definitions: `5xx Error Rate`, and an `Anonymous Access Anomaly` that only exists on private buckets.
- **IaC code** (`src/`) — a placeholder module that wires `params` into `massdriver_resource` outputs. Replace it with your real bucket module (S3, GCS, Azure Blob, MinIO, whatever you run).

## Customize it

1. Edit `massdriver.yaml` — match the params to your real bucket module's inputs (region, KMS keys, replication targets, and so on). The [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) covers every key.
2. Rewrite `src/` to be your real Terraform/OpenTofu. `_massdriver_variables.tf` regenerates from your params and connections on every `mass bundle build`, so the schema and the variables stay in sync.
3. Update `operator.md` with your team's actual runbook — public-access incident response, lifecycle policy debugging, restore-from-versioning procedure.
4. Tune the alarm definitions in `src/alarms.tf` to thresholds your team will actually wake up for.
