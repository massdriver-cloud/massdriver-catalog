---
templating: mustache
---

# PostgreSQL runbook

## I need a psql session on this database right now

```bash
psql -h {{artifacts.database.auth.hostname}} \
     -p {{artifacts.database.auth.port}} \
     -U {{artifacts.database.auth.username}} \
     -d {{artifacts.database.auth.database}} -W
```

`-W` makes psql prompt for the password instead of taking it on the command line, where it would
land in your shell history and in `ps` output. Get the value from this instance's database
resource in Massdriver — the field is marked sensitive, so opening it is audit-logged — or from
`DATABASE_PASSWORD` inside a connected app's container.

For a client that wants a DSN, use
`postgresql://{{artifacts.database.auth.username}}@{{artifacts.database.auth.hostname}}:{{artifacts.database.auth.port}}/{{artifacts.database.auth.database}}`
and let the client prompt for the password. A DSN with the password baked into it is a full
credential in one string — it does not belong in a ticket, a chat message, or a `.env` you will
forget about.

## The "High Connections" alarm fired, or new connections are timing out

The connection pool is saturating. Once it fills, every new connection is refused. Usual causes:
a deploy that leaks connections, a cache restart hammering the database, or a queue worker
fanning out.

Find who is holding the connections:

```sql
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

Sessions sitting in `idle in transaction` hold both a connection and their locks. Cut the ones
older than five minutes loose:

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '{{artifacts.database.auth.database}}'
  AND state = 'idle in transaction'
  AND state_change < now() - interval '5 minutes';
```

If you recognise the application, redeploy it with a smaller pool. If you cannot identify the
source, buy time by moving this instance up one size (it is `{{params.instance_size}}` today) and
open an incident:

```bash
mass instance deploy {{slug}} -P '.instance_size = "m"' -m "temporary size bump, connection storm" -f
```

## The "Storage 80% Full" alarm fired, or writes are being refused

PostgreSQL stops accepting writes as the disk approaches full. Work through this in order.

Where the space is going:

```sql
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 10;
```

Dead tuples that autovacuum has not reclaimed:

```sql
SELECT
  relname,
  n_dead_tup,
  pg_size_pretty(pg_relation_size(relid)) AS size
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 10;
```

Total size, so you can tell whether anything you did actually helped:

```bash
psql -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} \
     -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}} -W \
     -c "SELECT pg_size_pretty(pg_database_size('{{artifacts.database.auth.database}}'));"
```

Cheapest fix first: `VACUUM (FULL)` the most bloated table — it takes an exclusive lock, so that
table is unreadable for the duration. Then drop indexes nothing uses. Then add disk:

```bash
mass instance deploy {{slug}} -P '.allocated_storage_gb = 200' -m "storage 80% full" -f
```

It is allocated `{{params.allocated_storage_gb}} GB` now. Storage grows online, but most cloud
providers cannot shrink it again, so do not overshoot by an order of magnitude.

## The "Replication Lag" alarm fired, and a failover right now would lose data

{{#params.high_availability}}
Ask the primary how far behind the standby is:

```sql
SELECT
  client_addr,
  state,
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
FROM pg_stat_replication;
```

Usual causes: a long-running transaction on the primary blocking WAL apply on the standby,
saturated network between availability zones, or a standby smaller than the primary. If
`lag_bytes` keeps climbing, do not fail over — you would be promoting a copy that is missing
committed transactions. Page the on-call DBA.
{{/params.high_availability}}
{{^params.high_availability}}
`high_availability` is off on this instance, so there is no standby and this alarm does not
exist here. Turn HA on and redeploy if you need one — it roughly doubles the cost.
{{/params.high_availability}}

## The primary is unresponsive and I need to fail over

Use the failover action on this instance in Massdriver first. If that is unavailable, the cloud
provider's own CLI does the same thing:

```bash
aws rds reboot-db-instance --db-instance-identifier {{artifacts.database.id}} --force-failover
```

{{^params.high_availability}}
There is no standby on this instance, so there is nothing to fail over to. Recovery here means
restoring a backup onto a new instance. Backups are kept for `{{params.backup_retention_days}}`
days.
{{/params.high_availability}}

## I need a dump before I do something risky

Automatic backups cover the last `{{params.backup_retention_days}}` days, but they restore the
whole instance. For a single table, a schema change, or a migration you want to be able to undo
in minutes, take your own dump first:

```bash
pg_dump -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} \
        -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}} -W \
        -F c -f backup-{{artifacts.database.auth.database}}-$(date +%Y%m%d-%H%M%S).dump
```

Putting it back, into a database that already exists:

```bash
pg_restore -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} \
           -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}} -W \
           --clean --if-exists \
           backup-{{artifacts.database.auth.database}}-20260514-021500.dump
```

`--clean --if-exists` drops each object before recreating it. On a database that is still taking
writes, that is destructive — restore into a fresh instance unless you have already stopped the
apps.

## Changing `database_name`, `username`, or `db_version`

All three are immutable, so the form will not let you edit them. Changing any one of them means a
different instance, and the data goes with the old one when you destroy it.

1. Take a dump (above).
2. Deploy a second postgres instance with the new values. Today's are
   `{{artifacts.database.auth.database}}` / `{{artifacts.database.auth.username}}` / PostgreSQL
   `{{artifacts.database.version}}`.
3. Restore the dump into it.
4. Re-link each consuming app to the new instance on the canvas, then redeploy those apps. Until
   an app is redeployed it keeps the old connection details in its environment.
5. Once the apps are serving from the new instance, destroy the old one:

```bash
mass instance destroy {{slug}}
```
