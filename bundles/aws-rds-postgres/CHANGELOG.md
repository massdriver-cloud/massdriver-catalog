# Changelog

All notable changes to the `aws-rds-postgres` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Real OpenTofu RDS PostgreSQL instance: subnet group over the network's private subnets, security group open only to the VPC CIDR on 5432, generated 32-character password, encrypted storage.
- `instance_size` t-shirt selector (`xs`–`l`) mapped to instance classes in a Terraform local.
- `placement_subnet` `$md.enum` dropdown fed by the connected `aws-network` resource; pins the primary's availability zone when high availability is off.
- `high_availability` toggle wired to RDS Multi-AZ.
- Conditional `dependencies` block: `max_storage_gb` required only when `storage_autoscaling` is on.
- `params.examples`: Development / Staging / Production presets.
- `$md.immutable` on `db_version`, `database_name`, and `username`; `$md.copyable: false` on `username`.
- Alarms: `High Connections`, `CPU High`, `Storage Low` (20% of allocated), and `Replication Lag` when HA is enabled.
- Emits a `postgres-database` resource with connection details and `read-only` / `read-write` policies.
