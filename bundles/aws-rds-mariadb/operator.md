---
templating: mustache
---

# MariaDB Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Host | `{{artifacts.database.auth.hostname}}` |
| Port | `{{artifacts.database.auth.port}}` |
| Database | `{{artifacts.database.auth.database}}` |
| Username | `{{artifacts.database.auth.username}}` |
| Version | `{{artifacts.database.version}}` |
| High availability | `{{params.high_availability}}` |
| Slow query log | `{{params.slow_query_log_enabled}}` |

### Connecting with the mysql CLI

The password is never written into this runbook. Get it from the `database` resource on this instance's page in Massdriver (the download is audit-logged), then:

```bash
mysql -h {{artifacts.database.auth.hostname}} \
      -P {{artifacts.database.auth.port}} \
      -u {{artifacts.database.auth.username}} \
      -p {{artifacts.database.auth.database}}
```

You must be on a machine inside the VPC (a pod, a bastion, or an SSM session) — the database does not accept connections from the internet.

---

## Active alarms — what they mean

### High Connections

More than 80 open connections for 5 minutes. WordPress under load with no connection reuse is the usual cause, or a crashed app leaving connections open.

```sql
-- Who is connected, and what are they doing?
SHOW PROCESSLIST;
```

**Fix now:** kill runaway connections (`KILL <id>;`) or restart the offending app.
**Fix later:** put a connection pooler (like ProxySQL) in front, or raise `instance_size` — bigger classes allow more connections.

### Storage Low

Free disk dropped below 20% of what was allocated. MariaDB stops accepting writes when disk hits zero, and recovery from a full disk is painful.

**Fix now:** raise `allocated_storage_gb` and redeploy — RDS grows disks online, no downtime.
**Fix later:** find what grew. Common culprits: binary logs held by long `backup_retention_days`, or a runaway table (`SELECT table_schema, table_name, ROUND((data_length+index_length)/1024/1024) AS mb FROM information_schema.tables ORDER BY mb DESC LIMIT 10;`).

### Replication Lag

The standby is more than 30 seconds behind. A failover right now would lose recent writes. Usually caused by a burst of writes (bulk import, big migration). If it does not recover once the burst ends, contact AWS support.

## "WordPress can't connect"

Work top to bottom — the first three cover almost every case:

1. **Wrong host or credentials in the app.** WordPress should get its `DB_HOST`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD` from the connected `database` resource, not hand-typed values. If someone pasted values, they go stale.
2. **The app is outside the VPC.** Port 3306 is only open to the connected network's CIDR. Test from where the app actually runs: `nc -zv {{artifacts.database.auth.hostname}} {{artifacts.database.auth.port}}`. A timeout means a network problem; "connection refused" means you reached the box but the database is down.
3. **Too many connections.** The error says so explicitly (`ERROR 1040`). See the High Connections alarm above.
4. **The instance is rebooting or failing over.** Check recent events: `aws rds describe-events --source-identifier {{slug}} --source-type db-instance --duration 60`.

## "Text looks garbled" (Ã©, â€™, ?? instead of accents and emoji)

This is a character-set mismatch, not data loss — usually.

1. Check what the server is set to: `SHOW VARIABLES LIKE 'character_set_server';`. This bundle sets it from `params.character_set` = `{{params.character_set}}`.
2. If the server is `utf8mb4` but text displays wrong, the **client** connection is the problem. For WordPress, set `DB_CHARSET` to `utf8mb4` in `wp-config.php`.
3. If someone wrote utf8 data into a `latin1` table, individual tables need converting: `ALTER TABLE <name> CONVERT TO CHARACTER SET utf8mb4 COLLATE {{params.collation}};`. Take a backup first — this rewrites the table.
4. Do **not** change the bundle's `character_set` param expecting a fix — it is immutable, and changing the server default never converts existing rows anyway.

## "The site is slow"

1. Turn on the slow query log if it is off (`slow_query_log_enabled` param), redeploy, and wait for traffic.
2. Read what it caught:

   ```sql
   -- The log lands in a table when written by the parameter group
   SELECT start_time, query_time, LEFT(sql_text, 120)
   FROM mysql.slow_log ORDER BY start_time DESC LIMIT 20;
   ```

3. The usual WordPress offenders: `wp_options` scans with no index on `autoload`, and `wp_postmeta` joins. `EXPLAIN` the query and add the missing index.
4. If queries are indexed but still slow, the working set has outgrown memory — raise `instance_size`.
