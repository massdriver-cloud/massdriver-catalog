# AWS RDS PostgreSQL

A single PostgreSQL instance on AWS RDS, placed on the connected network's private subnets, with a generated password, optional Multi-AZ standby, optional storage autoscaling, and encrypted storage. The stateful workhorse most applications connect to.

## What it shows

- **Placement dropdown from a linked resource** — the showcase here. `placement_subnet` uses `$md.enum` to read the subnet list straight out of the connected `aws-network` resource, so developers pick a real subnet from a dropdown instead of pasting IDs. The IaC then pins the primary to that subnet's availability zone (single-AZ only — Multi-AZ manages its own placement).
- **Self-service experience** — Development / Staging / Production presets, t-shirt `instance_size` labels that name the actual instance class and cost tier, immutable `db_version` / `database_name` / `username` with friendly validation messages, and a conditional `max_storage_gb` field that only becomes required when storage autoscaling is on. `username` is marked non-copyable so it never carries into cloned environments.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live instance's endpoint: connection exhaustion, disk filling up, and what to do right after a failover.
- **Compliance** — storage encryption and private-only access are hardcoded; Multi-AZ, backups, and deletion protection stay visible as Checkov warnings in dev instead of being skipped.
- **IaC code** (`src/`) — real, minimal OpenTofu: subnet group, purpose-scoped security group open only to the VPC CIDR on 5432, generated 32-character password, and four RDS health alarms.

## What it produces

A `postgres-database` resource: instance ARN, version, HA flag, connection details (hostname, port, database, username, generated password), and `read-only` / `read-write` access policies downstream bundles can offer in their own `$md.enum` dropdowns.

## Costs to know about

The instance is the bill: `db.t4g.micro` (Extra Small) runs ~$12/mo, `db.r6g.large` (Large) ~$160/mo, and enabling high availability roughly doubles whichever you pick. Storage adds ~$0.115/GB-mo (gp2).

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
