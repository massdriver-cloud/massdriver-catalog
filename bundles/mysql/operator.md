---
templating: mustache
---

# MySQL Runbook

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
| Character set | `{{params.character_set}}` |
| Collation | `{{params.collation}}` |
| Instance size | `{{params.instance_size}}` |
| Storage | `{{params.allocated_storage_gb}} GB` |
| HA | `{{params.high_availability}}` |
| Backup retention | `{{params.backup_retention_days}}d` |
| Slow log | `{{params.slow_query_log_enabled}}` |
| Network | `{{connections.network.id}}` ({{connections.network.cidr}}) |

---

## Connecting in a hurry

```bash
mysql \
  -h {{artifacts.database.auth.hostname}} \
  -P {{artifacts.database.auth.port}} \
  -u {{artifacts.database.auth.username}} \
  -p'{{artifacts.database.auth.password}}' \
  {{artifacts.database.auth.database}}
```

Connection string form:

```
mysql://{{artifacts.database.auth.username}}:{{artifacts.database.auth.password}}@{{artifacts.database.auth.hostname}}:{{artifacts.database.auth.port}}/{{artifacts.database.auth.database}}
```

> Avoid pasting the password into chat — share via your secret manager.

---

## Active alarms — what they mean

### Slow Query Rate (> 50/5min)

A query, or a small set of queries, is regularly missing the `{{params.slow_query_log_long_query_time_seconds}}s` threshold. App requests are likely timing out.

```bash
# Top offenders from the slow query log
mysql -h {{artifacts.database.auth.hostname}} -P {{artifacts.database.auth.port}} \
      -u {{artifacts.database.auth.username}} -p'{{artifacts.database.auth.password}}' \
      mysql -e "
SELECT
  query_time,
  rows_examined,
  rows_sent,
  CONVERT(sql_text USING utf8) AS query
FROM mysql.slow_log
WHERE start_time > NOW() - INTERVAL 1 HOUR
ORDER BY query_time DESC
LIMIT 20;"
```

```sql
-- Performance schema — running queries right now
SELECT
  CONCAT(USER, '@', HOST) AS user,
  DB,
  TIME,
  STATE,
  SUBSTR(INFO, 1, 120) AS query
FROM information_schema.processlist
WHERE COMMAND != 'Sleep'
ORDER BY TIME DESC;
```

```sql
-- Get the EXPLAIN for one of them
EXPLAIN ANALYZE <paste the slow query here>;
```

Fixes: add the missing index, rewrite the query, or use a covering index. If the query is from a known ORM, add a hint via the framework.

### Replication Lag (> 30s) — HA only

The replica is falling behind. A failover right now would lose committed data.

```sql
-- Run against the primary
SHOW REPLICAS;

-- Run against the replica
SHOW REPLICA STATUS\G
-- Look at: Seconds_Behind_Source, Replica_IO_Running, Replica_SQL_Running, Last_Errno
```

Common causes: long-running write on the primary holding row locks the replica must wait for; replica under-sized; cross-AZ network saturation.

### Storage 80% Full

```sql
-- Where's the space going?
SELECT
  table_schema,
  table_name,
  ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) AS gb
FROM information_schema.tables
WHERE table_schema = '{{artifacts.database.auth.database}}'
GROUP BY table_schema, table_name
ORDER BY gb DESC
LIMIT 10;
```

```sql
-- Binary log size (often the surprise culprit)
SHOW BINARY LOGS;
PURGE BINARY LOGS BEFORE NOW() - INTERVAL 3 DAY;  -- only if you control replication and have alternate copies
```

If you can't free space, bump `allocated_storage_gb` and redeploy.

---

## Common operations

### Database size

```bash
mysql -h {{artifacts.database.auth.hostname}} -P {{artifacts.database.auth.port}} \
      -u {{artifacts.database.auth.username}} -p'{{artifacts.database.auth.password}}' \
      -e "SELECT table_schema, ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
          FROM information_schema.tables
          WHERE table_schema = '{{artifacts.database.auth.database}}'
          GROUP BY table_schema;"
```

### Take a backup

```bash
mysqldump \
  -h {{artifacts.database.auth.hostname}} -P {{artifacts.database.auth.port}} \
  -u {{artifacts.database.auth.username}} -p'{{artifacts.database.auth.password}}' \
  --single-transaction --routines --triggers --events \
  {{artifacts.database.auth.database}} \
  > backup-{{artifacts.database.auth.database}}-$(date +%Y%m%d-%H%M%S).sql
```

### Restore

```bash
mysql \
  -h {{artifacts.database.auth.hostname}} -P {{artifacts.database.auth.port}} \
  -u {{artifacts.database.auth.username}} -p'{{artifacts.database.auth.password}}' \
  {{artifacts.database.auth.database}} \
  < backup-{{artifacts.database.auth.database}}-YYYYMMDD-HHMMSS.sql
```

### Kill long-running queries

```sql
-- List longest queries
SELECT id, time, state, info
FROM information_schema.processlist
WHERE command != 'Sleep' AND time > 60
ORDER BY time DESC;

-- Kill by ID
KILL QUERY <id>;
```

---

## Disaster recovery

`database_name`, `username`, `db_version`, `character_set`, and `collation` are **immutable**. Changing any of them in Massdriver triggers a destroy and recreate.

Migration playbook:

1. `mysqldump` the existing database (see above).
2. Deploy a new mysql bundle instance with the new values.
3. Restore the dump into the new instance.
4. Update each consuming app's connection link to point at the new instance.
5. Verify, then destroy the old instance.

---

**Edit this runbook:** https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/mysql/operator.md
