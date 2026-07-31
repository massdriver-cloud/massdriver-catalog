---
templating: mustache
---

# Postgres Runbook

## Alarms

### High connection count

The connection count is approaching the instance class's limit. New connections fail with "too many clients already."

```bash
aws rds describe-db-instances --db-instance-identifier {{artifacts.database.id}} \
  --query 'DBInstances[0].{Class:DBInstanceClass,Status:DBInstanceStatus}'
```

Quick relief: find and terminate idle or leaked connections.

```sql
SELECT pid, state, now() - state_change AS idle_for, query
FROM pg_stat_activity
WHERE state = 'idle' AND now() - state_change > interval '10 minutes'
ORDER BY idle_for DESC;
```

The usual root cause is an app-side connection pool that is oversized or not returning connections. Longer term: size up the instance class or add PgBouncer in front.

### Storage nearly full

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value={{artifacts.database.id}} \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Minimum
```

`allocated_storage_gb` grows online: raise it and redeploy, no downtime. Decreasing it requires a dump and restore.

{{#params.multi_az}}
### Replication lag (Multi-AZ)

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value={{artifacts.database.id}} \
  --start-time $(date -u -d '30 minutes ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 60 --statistics Maximum
```
{{/params.multi_az}}

## Common operations

### Connect with psql

```bash
PGPASSWORD='<paste from the instance panel>' psql \
  -h {{artifacts.database.auth.hostname}} \
  -p {{artifacts.database.auth.port}} \
  -U {{artifacts.database.auth.username}} \
  -d {{artifacts.database.auth.database}}
```

### Ad-hoc backup

```bash
PGPASSWORD='<paste>' pg_dump \
  -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} \
  -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}} \
  -F c -f backup-$(date +%F).dump
```

### Restore from an automated backup

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier {{artifacts.database.id}} \
  --target-db-instance-identifier {{artifacts.database.id}}-restored \
  --restore-time <ISO8601 timestamp>
```

This creates a new instance rather than overwriting the existing one. Point apps at the restored instance only after verifying its data.

## Disaster recovery

{{#params.deletion_protection}}
Deletion protection is on. The instance cannot be decommissioned until the setting is disabled.
{{/params.deletion_protection}}
{{^params.deletion_protection}}
Deletion protection is off. Enable it before the next deploy if this database holds data you need to keep.
{{/params.deletion_protection}}

`database_name` and `username` are immutable. A rename requires a new instance and a data migration, not a parameter change.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-rds-postgres/operator.md
