# Changelog

All notable changes to the `aws-rds-mariadb` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Real OpenTofu RDS MariaDB: subnet group over the network's private subnets, security group scoped to the VPC CIDR on port 3306, parameter group, encrypted instance.
- `instance_size` t-shirt selector (xs/s/m/l) mapped to db.t4g / db.r6g classes in a local.
- `params.examples`: Development / Production presets.
- `$md.immutable` on `db_version`, `database_name`, `username`, `character_set`, and `collation`; friendly `message.pattern` overrides on names.
- Conditional `dependencies` block: `slow_query_log_seconds` required only when `slow_query_log_enabled` is on; wired into the parameter group as `slow_query_log` + `long_query_time`.
- Generated 32-character URI-safe password via `random_password`.
- Instance alarms: `High Connections` (DatabaseConnections), `Storage Low` (FreeStorageSpace below 20% of allocated), and `Replication Lag` when high availability is on.
- Emits a `mysql-database` resource with connection details and Read / Write access policies for downstream `$md.enum` dropdowns. Consumed by `k8s-wordpress`.
