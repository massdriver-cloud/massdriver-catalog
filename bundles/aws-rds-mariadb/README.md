# AWS RDS MariaDB

A MariaDB database on AWS RDS, placed in the connected network's private subnets and reachable only from inside the VPC. This is the database behind the org's `k8s-wordpress` deployments — MariaDB speaks the MySQL protocol, so anything that connects to MySQL connects to it.

## What it shows

- **Self-service experience** — Development / Production presets, t-shirt instance sizes with the real class in the label, `$md.immutable` on version, names, character set, and collation (the things you can't safely change on a live database), and a slow-query threshold field that only appears when the slow-query log is on.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live endpoint: "WordPress can't connect", garbled-text (charset) triage, and slow-query triage.
- **Compliance** — storage encrypted, never publicly accessible, port 3306 open only to the VPC's CIDR. Deletion-protection and Multi-AZ findings surface as Checkov warnings in dev instead of being skipped.
- **IaC code** (`src/`) — real, minimal OpenTofu: subnet group, security group, parameter group (character set, collation, conditional slow-query log), instance, and three RDS alarms wired to the health panel.

## What it produces

A `mysql-database` resource: instance ARN, version, HA flag, connection details (host, port, database, username, generated password), and Read / Write access policies for downstream `$md.enum` dropdowns.

## Costs to know about

The Extra Small preset (db.t4g.micro) runs about $12/mo plus storage (gp2 is ~$0.115/GB-mo). High availability doubles the instance cost. Large (db.r6g.large) is ~$165/mo before storage.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
