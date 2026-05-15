---
templating: mustache
---

# PostgreSQL Runbook

> **Templating context:** `slug`, `params`, `connections.<name>`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Database ID | `{{artifacts.database.id}}` |
| Version | `{{artifacts.database.version}}` |
| Host | `{{artifacts.database.auth.hostname}}` |
| Port | `{{artifacts.database.auth.port}}` |
| Database | `{{artifacts.database.auth.database}}` |
| Username | `{{artifacts.database.auth.username}}` |
| Instance size | `{{params.instance_size}}` |
| Storage | `{{params.allocated_storage_gb}} GB` |
| HA | `{{params.high_availability}}` |
| Backup retention | `{{params.backup_retention_days}}d` |
| Network | `{{connections.network.id}}` ({{connections.network.cidr}}) |

---

## Connecting in a hurry

```bash
PGPASSWORD={{artifacts.database.auth.password}} psql \
  -h {{artifacts.database.auth.hostname}} \
  -p {{artifacts.database.auth.port}} \
  -U {{artifacts.database.auth.username}} \
  -d {{artifacts.database.auth.database}}
```

Connection string form (for tools that want a DSN):

```
postgresql://{{artifacts.database.auth.username}}:{{artifacts.database.auth.password}}@{{artifacts.database.auth.hostname}}:{{artifacts.database.auth.port}}/{{artifacts.database.auth.database}}
```

> The password above is rendered from the deployed resource. Avoid copying it into chat or tickets — share via your secret manager.

---

## Active alarms — what they mean

### High Connections (> 80)

The pool is saturating. New connections will start timing out. Common causes: a deploy that leaks connections, an in-memory cache restart hammering the DB, or a queue worker fan-out.

```sql
-- Top offenders right now
SELECT
  application_name,
  client_addr,
  state,
  count(*) AS conns,
  sum(EXTRACT(EPOCH FROM (now() - state_change))) AS sec_in_state
FROM pg_stat_activity
WHERE datname = '{{artifacts.database.auth.database}}'
GROUP BY application_name, client_addr, state
ORDER BY conns DESC;
```

```sql
-- Kill idle-in-transaction sessions older than 5 minutes
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '{{artifacts.database.auth.database}}'
  AND state = 'idle in transaction'
  AND state_change < now() - interval '5 minutes';
```

If the offender is a known application, redeploy with a smaller pool. If you can't identify the source, scale the database **temporarily** (next size up) and open an incident.

### Storage 80% Full

Disk pressure. PostgreSQL stops accepting writes near 100%. Order of triage:

```sql
-- Where is the space going?
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 10;
```

```sql
-- Bloat from un-vacuumed dead tuples
SELECT
  relname,
  n_dead_tup,
  pg_size_pretty(pg_relation_size(relid)) AS size
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 10;
```

Fixes, in order: `VACUUM (FULL)` a known-bloated table (locks it!), drop unneeded indexes, increase `allocated_storage_gb` on this bundle's parameters and redeploy.

### Replication Lag (> 30s) — HA only

The standby is falling behind primary. Failover within the next few minutes would lose committed data.

```sql
-- From primary
SELECT
  client_addr,
  state,
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
FROM pg_stat_replication;
```

Common causes: long-running transaction on the primary blocking WAL apply on the replica, network saturation between AZs, or under-sized replica. Page the on-call DBA if lag keeps growing.

---

## Common operations

### Database size

```bash
PGPASSWORD={{artifacts.database.auth.password}} psql \
  -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} \
  -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}} \
  -c "SELECT pg_size_pretty(pg_database_size('{{artifacts.database.auth.database}}'));"
```

### Take a backup (out-of-band)

```bash
PGPASSWORD={{artifacts.database.auth.password}} pg_dump \
  -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} \
  -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}} \
  -F c -f backup-{{artifacts.database.auth.database}}-$(date +%Y%m%d-%H%M%S).dump
```

### Restore from a `pg_dump -F c` file

```bash
PGPASSWORD={{artifacts.database.auth.password}} pg_restore \
  -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} \
  -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}} \
  --clean --if-exists \
  backup-{{artifacts.database.auth.database}}-YYYYMMDD-HHMMSS.dump
```

### Manually trigger failover (HA only)

Use the bundle's failover button in Massdriver. If that's unavailable, your cloud provider's CLI:

```bash
# AWS RDS example
aws rds reboot-db-instance --db-instance-identifier {{artifacts.database.id}} --force-failover
```

---

## Disaster recovery

`database_name`, `username`, and `db_version` are **immutable**. Changing any of them in Massdriver triggers a destroy and recreate — your data goes with the instance.

If you need to change any of those, follow the migration playbook:

1. Take an out-of-band backup (see above).
2. Deploy a new postgres bundle instance with the new values.
3. Restore the dump into the new instance.
4. Update each consuming app's connection link to point at the new instance.
5. Verify, then destroy the old instance.

---

**Edit this runbook:** https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/postgres/operator.md
