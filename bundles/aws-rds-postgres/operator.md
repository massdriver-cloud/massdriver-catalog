---
templating: mustache
---

# PostgreSQL Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Endpoint | `{{artifacts.database.auth.hostname}}:{{artifacts.database.auth.port}}` |
| Database | `{{artifacts.database.auth.database}}` |
| Username | `{{artifacts.database.auth.username}}` |
| Version | PostgreSQL `{{artifacts.database.version}}` |
| High availability | `{{params.high_availability}}` |
| Instance size | `{{params.instance_size}}` |
| Backup retention | `{{params.backup_retention_days}}` days |

## Connect

```bash
psql "host={{artifacts.database.auth.hostname}} port={{artifacts.database.auth.port}} dbname={{artifacts.database.auth.database}} user={{artifacts.database.auth.username}} sslmode=require"
```

The password is not printed here. Get it from the **database resource** on this instance's page in Massdriver — it's masked in the UI and downloads are audit-logged.

---

## Active alarms — what they mean

### High Connections

More than 80 concurrent connections. Small instance classes fall over well before Postgres's own limit, and each idle connection still costs memory.

```sql
-- Who is holding connections, and are they doing anything?
SELECT usename, state, count(*) FROM pg_stat_activity GROUP BY 1, 2 ORDER BY 3 DESC;

-- Kill idle-in-transaction sessions older than 10 minutes
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE state = 'idle in transaction' AND state_change < now() - interval '10 minutes';
```

**Fix now:** terminate idle sessions (above), or restart the leaking app.
**Fix later:** put a connection pooler (PgBouncer / RDS Proxy) in front of the app, or bump `instance_size`.

### Storage Low

Free disk dropped below 20% of allocated. If the disk actually fills, RDS puts the instance in `storage-full` and writes stop.

```sql
-- What's eating the disk?
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;
```

**Fix now:** raise `allocated_storage_gb` and redeploy (grows online, no downtime), or turn on `storage_autoscaling`.
**Fix later:** check for table/WAL bloat — a `VACUUM FULL` during a window, or long-running transactions pinning WAL.

### CPU High

Sustained CPU above 90%. Usually one bad query, not organic growth.

```sql
-- Longest-running statements right now
SELECT pid, now() - query_start AS runtime, left(query, 80)
FROM pg_stat_activity WHERE state = 'active' ORDER BY runtime DESC LIMIT 10;
```

**Fix now:** `SELECT pg_cancel_backend(<pid>)` on the offender.
**Fix later:** add the missing index, or move up a t-shirt size if it's genuinely load.

### Replication Lag (HA only)

The standby is more than 30 seconds behind. Failover during heavy lag takes longer and risks a slow recovery. Heavy writes (bulk loads, big migrations) are the usual cause — let it drain before doing anything that could trigger a failover.

---

## "A failover just happened"

Multi-AZ failover swaps the primary to the standby; the endpoint hostname stays the same but the underlying IP changes.

1. Apps with cached DNS or stale pooled connections will error until they reconnect — restart anything that hasn't recovered within a couple of minutes.
2. Check why it failed over:

   ```bash
   aws rds describe-events --source-identifier {{slug}} --source-type db-instance --duration 120
   ```

3. An AZ issue is AWS's problem; repeated failovers with no AWS event mean the instance is undersized (check the CPU and connection alarms above).

## "I need to restore from backup"

Automatic backups keep `{{params.backup_retention_days}}` days of point-in-time recovery. Restores always create a **new** instance — you can't restore in place. Restore via the AWS console or `aws rds restore-db-instance-to-point-in-time`, then repoint apps or dump/load back. Talk to the platform team before starting; this is a coordination problem, not a solo fix.
