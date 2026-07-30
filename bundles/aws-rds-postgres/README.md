# Postgres Database

Provisions an Amazon RDS for PostgreSQL instance in the connected network's private subnets, with encrypted storage and an optional Multi-AZ standby. Emits a `postgres-server` resource with the connection host, port, database, and credentials.

## Why provisioned RDS rather than Aurora Serverless v2

Aurora Serverless v2 has a cost floor: at its minimum of 0.5 ACU it bills roughly $44/month of compute before storage and I/O charges. A small provisioned instance (`db.t4g.micro`, the `xs` size here) runs about a quarter of that for workloads this size, with no scaling behavior to reason about. If an app later develops sustained high or bursty load, Aurora Serverless can be reconsidered for that app specifically.

## What it provisions

- A private database instance, reachable only from inside the network. Storage is encrypted at rest.
- Automated backups with configurable retention (up to 35 days).
- An optional synchronous standby in a second availability zone (`multi_az`) with automatic failover. A standby roughly doubles instance cost.
- Deletion protection, on by default.

## Parameters worth knowing

- `database_name` and `username` are immutable. The password is generated and rotated by the provisioner and is only exposed to IaC at deploy time.
- `allocated_storage_gb` can be increased online; decreasing requires a dump and restore to a new instance.
- `skip_final_snapshot` skips the final snapshot on destroy; leave it off for instances holding data you need to keep.

## Operational notes

- `src/main.tf` provisions the RDS instance, subnet group, and security group.
- `operator.md` covers connection troubleshooting, point-in-time restore, and failover; update it with your team's own procedures.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
