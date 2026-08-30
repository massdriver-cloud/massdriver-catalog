---
templating: mustache
---

# MySQL runbook

## I need a mysql session on this database right now

```bash
mysql -h {{artifacts.database.auth.hostname}} \
      -P {{artifacts.database.auth.port}} \
      -u {{artifacts.database.auth.username}} -p \
      {{artifacts.database.auth.database}}
```

`-p` with no value attached makes mysql prompt for the password instead of taking it on the
command line, where it would land in your shell history and in `ps` output. Get the value from
this instance's database resource in Massdriver — the field is marked sensitive, so opening it is
audit-logged — or from `DATABASE_PASSWORD` inside a connected app's container.

For a client that wants a DSN, use
`mysql://{{artifacts.database.auth.username}}@{{artifacts.database.auth.hostname}}:{{artifacts.database.auth.port}}/{{artifacts.database.auth.database}}`
and let the client prompt for the password. A DSN with the password baked into it is a full
credential in one string — it does not belong in a ticket, a chat message, or a `.env` you will
forget about.

## The "Slow Query Rate" alarm fired, or requests are timing out

{{#params.slow_query_log_enabled}}
Something is regularly crossing the
`{{params.slow_query_log_long_query_time_seconds}}s` threshold. Start with the worst offenders of
the last hour — the slow log lives in the `mysql` schema, not in your application database:

```bash
mysql -h {{artifacts.database.auth.hostname}} -P {{artifacts.database.auth.port}} \
      -u {{artifacts.database.auth.username}} -p mysql -e "
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

A large `rows_examined` next to a small `rows_sent` is the signature of a missing index.
{{/params.slow_query_log_enabled}}
{{^params.slow_query_log_enabled}}
`slow_query_log_enabled` is off, so there is no slow log to read and this alarm does not exist on
this instance. Turn it on and redeploy if you are trying to catch a slow query — it costs disk,
so turn it back off afterwards on a small instance:

```bash
mass instance deploy {{slug}} -P '.slow_query_log_enabled = true' -m "catching a slow query" -f
```
{{/params.slow_query_log_enabled}}

What is running this instant:

```sql
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

Take the worst statement from either list and ask MySQL where the time goes:

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42 ORDER BY created_at DESC LIMIT 50;
```

Fixes, in the order they usually work: add the missing index, make it a covering index, or
rewrite the query. If the statement comes out of an ORM, the fix belongs in the application, not
here.

## The "Replication Lag" alarm fired, and a failover right now would lose data

{{#params.high_availability}}
Against the primary:

```sql
SHOW REPLICAS;
```

Against the replica:

```sql
SHOW REPLICA STATUS\G
```

Read `Seconds_Behind_Source`, `Replica_IO_Running`, `Replica_SQL_Running` and `Last_Errno`. Both
`Running` values must be `Yes`; a non-zero `Last_Errno` means replication has stopped rather than
fallen behind, which is a different problem and will not recover on its own.

Usual causes: a long write on the primary holding row locks the replica has to wait for, a
replica smaller than the primary, or saturated network between availability zones.
{{/params.high_availability}}
{{^params.high_availability}}
`high_availability` is off on this instance, so there is no replica and this alarm does not exist
here. Turn HA on and redeploy if you need one — it roughly doubles the cost.
{{/params.high_availability}}

## The "Storage 80% Full" alarm fired, or writes are being refused

Where the space is going:

```sql
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

Binary logs are the usual surprise — they are not your data and they are not in the table sizes
above:

```sql
SHOW BINARY LOGS;
```

```sql
PURGE BINARY LOGS BEFORE NOW() - INTERVAL 3 DAY;
```

Only purge if you control replication and have another copy of those logs. A replica that has not
read a log you delete cannot catch up and has to be rebuilt.

If you cannot free enough space, add disk. It is allocated
`{{params.allocated_storage_gb}} GB` now:

```bash
mass instance deploy {{slug}} -P '.allocated_storage_gb = 200' -m "storage 80% full" -f
```

## One query is stuck and everything behind it is blocked

Find it:

```sql
SELECT id, time, state, info
FROM information_schema.processlist
WHERE command != 'Sleep' AND time > 60
ORDER BY time DESC;
```

Kill the statement using the `id` from that list, leaving the connection open so the application
sees an error rather than a dropped socket:

```sql
KILL QUERY 4821;
```

## I need a dump before I do something risky

Automatic backups cover the last `{{params.backup_retention_days}}` days, but they restore the
whole instance. For a schema change or a migration you want to undo in minutes, take your own
dump first:

```bash
mysqldump -h {{artifacts.database.auth.hostname}} -P {{artifacts.database.auth.port}} \
          -u {{artifacts.database.auth.username}} -p \
          --single-transaction --routines --triggers --events \
          {{artifacts.database.auth.database}} \
          > backup-{{artifacts.database.auth.database}}-$(date +%Y%m%d-%H%M%S).sql
```

`--single-transaction` gives a consistent snapshot without locking the tables, which is what you
want on an instance still serving traffic.

Putting it back:

```bash
mysql -h {{artifacts.database.auth.hostname}} -P {{artifacts.database.auth.port}} \
      -u {{artifacts.database.auth.username}} -p \
      {{artifacts.database.auth.database}} \
      < backup-{{artifacts.database.auth.database}}-20260514-021500.sql
```

A dump restored over a live database overwrites rows written since the dump was taken. Stop the
apps first, or restore into a fresh instance.

## Changing `database_name`, `username`, `db_version`, `character_set`, or `collation`

All five are immutable, so the form will not let you edit them. Changing any one of them means a
different instance, and the data goes with the old one when you destroy it.

1. Take a dump (above).
2. Deploy a second mysql instance with the new values. Today's are
   `{{artifacts.database.auth.database}}` / `{{artifacts.database.auth.username}}` / MySQL
   `{{artifacts.database.version}}` / `{{params.character_set}}` / `{{params.collation}}`.
3. Restore the dump into it. If you are changing the character set, check for mangled text in a
   few rows with accented or non-Latin characters before you trust the load.
4. Re-link each consuming app to the new instance on the canvas, then redeploy those apps. Until
   an app is redeployed it keeps the old connection details in its environment.
5. Once the apps are serving from the new instance, destroy the old one:

```bash
mass instance destroy {{slug}}
```
