---
templating: mustache
---

# AWS RDS PostgreSQL Operator Guide

> **Available context**: `slug`, `params`, `connections.<name>`, `artifacts.<name>`

## Connection Information

- **Hostname:** `{{artifacts.database.auth.hostname}}`
- **Port:** `{{artifacts.database.auth.port}}`
- **Database:** `{{artifacts.database.auth.database}}`
- **Username:** `{{artifacts.database.auth.username}}`

### Quick Connect

```bash
psql -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}}
```

---

## Troubleshooting Slow Queries with pg_stat_statements

The `pg_stat_statements` extension tracks execution statistics for all SQL statements. This is essential for identifying slow queries, finding optimization opportunities, and understanding database performance.

### Step 1: Enable pg_stat_statements

First, check if the extension is already enabled:

```sql
-- Connect to your database
psql -h {{artifacts.database.auth.hostname}} -p {{artifacts.database.auth.port}} -U {{artifacts.database.auth.username}} -d {{artifacts.database.auth.database}}

-- Check if extension exists
SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';
```

If not enabled, create it:

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

### Step 2: Find the Slowest Queries

#### Top 10 Queries by Total Execution Time

```sql
SELECT
    round(total_exec_time::numeric, 2) AS total_time_ms,
    calls,
    round(mean_exec_time::numeric, 2) AS avg_time_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) AS percent_total,
    query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

#### Top 10 Queries by Average Execution Time

```sql
SELECT
    round(mean_exec_time::numeric, 2) AS avg_time_ms,
    calls,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    query
FROM pg_stat_statements
WHERE calls > 10  -- Filter out rarely-executed queries
ORDER BY mean_exec_time DESC
LIMIT 10;
```

#### Top 10 Most Frequently Called Queries

```sql
SELECT
    calls,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    round(mean_exec_time::numeric, 2) AS avg_time_ms,
    query
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 10;
```

### Step 3: Analyze Specific Query Performance

Once you've identified a slow query, use `EXPLAIN ANALYZE` to understand its execution plan:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM your_table WHERE your_condition;
```

Key things to look for:
- **Seq Scan** on large tables (may need an index)
- **Nested Loop** with high row counts (may need query restructuring)
- **Sort** operations (may need index for ORDER BY)
- **Buffers: shared read** (high values indicate cache misses)

### Step 4: Find Missing Indexes

#### Tables with Sequential Scans (Potential Index Candidates)

```sql
SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    n_live_tup AS row_count,
    round((seq_tup_read::numeric / NULLIF(seq_scan, 0)), 2) AS avg_rows_per_seq_scan
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC
LIMIT 20;
```

#### Index Usage Statistics

```sql
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS times_used,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

#### Find Unused Indexes (Candidates for Removal)

```sql
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS times_used,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Step 5: Monitor Query Performance Over Time

#### Reset Statistics (Do This After Optimization)

```sql
-- Reset pg_stat_statements to start fresh measurements
SELECT pg_stat_statements_reset();
```

#### Check Database-Wide Statistics

```sql
SELECT
    datname AS database,
    numbackends AS active_connections,
    xact_commit AS commits,
    xact_rollback AS rollbacks,
    blks_read AS disk_blocks_read,
    blks_hit AS cache_hits,
    round((blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100), 2) AS cache_hit_ratio
FROM pg_stat_database
WHERE datname = '{{artifacts.database.auth.database}}';
```

### Step 6: Common Performance Issues and Solutions

#### Issue: High CPU from Repeated Queries

**Symptom:** Same query appears many times in pg_stat_statements with high total time but low mean time.

**Solution:** Implement application-level caching or use prepared statements.

```sql
-- Find queries that could benefit from caching
SELECT
    calls,
    round(mean_exec_time::numeric, 2) AS avg_ms,
    round(total_exec_time::numeric, 2) AS total_ms,
    query
FROM pg_stat_statements
WHERE calls > 1000 AND mean_exec_time < 10
ORDER BY calls DESC
LIMIT 10;
```

#### Issue: Slow Queries Due to Table Bloat

**Symptom:** Queries getting slower over time, high disk usage.

**Solution:** Check for table bloat and vacuum:

```sql
-- Check table sizes and dead tuples
SELECT
    schemaname,
    relname AS table_name,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    round((n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100), 2) AS dead_percent,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

```sql
-- Manual vacuum if needed (for specific table)
VACUUM ANALYZE your_table_name;
```

#### Issue: Lock Contention

**Symptom:** Queries waiting, application timeouts.

```sql
-- Find blocking queries
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_query,
    blocking_activity.query AS blocking_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

---

## Viewing Logs in CloudWatch

PostgreSQL logs are exported to CloudWatch Logs. You can view them in the AWS Console or via CLI:

```bash
# List recent log streams
aws logs describe-log-streams \
    --log-group-name "/aws/rds/instance/{{slug}}/postgresql" \
    --order-by LastEventTime \
    --descending \
    --limit 5

# Tail recent logs
aws logs tail "/aws/rds/instance/{{slug}}/postgresql" --follow
```

### Finding Slow Queries in Logs

Queries taking longer than 1 second are automatically logged. Search for them:

```bash
aws logs filter-log-events \
    --log-group-name "/aws/rds/instance/{{slug}}/postgresql" \
    --filter-pattern "duration:" \
    --start-time $(date -d '1 hour ago' +%s000)
```

---

## Performance Insights

This database has Performance Insights enabled with 7-day retention. Access it through:

1. AWS Console > RDS > Databases > `{{slug}}`
2. Click "Monitoring" tab
3. Select "Performance Insights"

Use Performance Insights to:
- Visualize database load over time
- Identify top SQL queries by load
- Analyze wait events (I/O, locks, CPU)
- Compare performance across time periods

---

## Emergency Procedures

### Kill a Long-Running Query

```sql
-- Find the PID of the query
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
AND state != 'idle';

-- Cancel the query (graceful)
SELECT pg_cancel_backend(<pid>);

-- Terminate the connection (forceful - use with caution)
SELECT pg_terminate_backend(<pid>);
```

### Check Current Connections

```sql
SELECT
    usename,
    client_addr,
    state,
    count(*)
FROM pg_stat_activity
GROUP BY usename, client_addr, state
ORDER BY count(*) DESC;
```

### Check Connection Limits

```sql
SELECT
    max_conn,
    used,
    max_conn - used AS available,
    round((used::numeric / max_conn * 100), 2) AS percent_used
FROM (SELECT count(*) AS used FROM pg_stat_activity) AS t,
     (SELECT setting::int AS max_conn FROM pg_settings WHERE name = 'max_connections') AS s;
```
