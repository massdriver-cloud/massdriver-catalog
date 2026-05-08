# AWS RDS PostgreSQL Runbook

It's 2am. The database is unhappy. Here's what to check.

## Connections are timing out

1. Confirm the workload's security group is allowed to reach the database SG (the `security_group_id` in the artifact).
2. If the workload is in a private subnet, verify the route to the RDS subnets is open.
3. Check `aws rds describe-db-instances --db-instance-identifier <id>` for `DBInstanceStatus`. If it's `modifying` or `rebooting`, wait it out — connections will resume.

## Reads are slow but writes are fine

If `read_replica_count > 0`, point read traffic at `auth.reader_endpoint` rather than the writer. The reader endpoint round-robins across replicas.

## Replication lag on the read replicas

CloudWatch metric `ReplicaLag` per replica. Sustained lag usually means writer IO saturation — check `WriteIOPS` and consider scaling the writer's `instance_class` or moving to `db.r6g`.

## Failover happened. Now what?

Multi-AZ failover is automatic. Apps using the writer hostname will reconnect once DNS updates (~30–90s). If your app caches DNS, force-reconnect after failover.

## Major version upgrade

Cannot be done in place safely without app review. Snapshot first, test the upgrade in a lower environment, schedule a maintenance window, and bump `engine_version`.

## Restoring from backup

Backups retained for `backup_retention_days`. Use point-in-time restore via the AWS console or `aws rds restore-db-instance-to-point-in-time` to a fresh instance — you cannot overwrite the running one.

## Granting workloads access

Each workload gets its own IAM role. Bind one of the policies in `database.policies` (read/write/admin) to that role. The example policies are starting points — tune them to your IAM strategy.
