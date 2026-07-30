---
templating: mustache
---

# Cache Runbook

## Alarms

### Evictions climbing

The cache is out of memory and dropping keys before they expire; sessions or cached data disappear under load.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache --metric-name Evictions \
  --dimensions Name=ReplicationGroupId,Value={{artifacts.cache.id}} \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Sum
```

Either increase `node_size`, or check for keys being written without a TTL that should have one.

### Connections maxed out

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache --metric-name CurrConnections \
  --dimensions Name=ReplicationGroupId,Value={{artifacts.cache.id}} \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Maximum
```

The usual cause is an app opening a new client per request instead of using a shared connection pool.

## Common operations

### Connect with redis-cli (TLS required)

```bash
redis-cli -h {{artifacts.cache.auth.hostname}} -p {{artifacts.cache.auth.port}} \
  --tls -a '<paste auth token from the instance panel>'
```

### Check memory usage and key count

```bash
redis-cli -h {{artifacts.cache.auth.hostname}} -p {{artifacts.cache.auth.port}} --tls -a '<token>' INFO memory
redis-cli -h {{artifacts.cache.auth.hostname}} -p {{artifacts.cache.auth.port}} --tls -a '<token>' DBSIZE
```

## Disaster recovery

{{#params.high_availability}}
Automatic failover is enabled. Losing the primary promotes the replica within seconds, with no manual action. Verify afterward with `INFO replication`.
{{/params.high_availability}}
{{^params.high_availability}}
There is no standby node. Losing this node loses every session and cached value it held; apps should handle a cold cache (re-authenticate, re-fetch) rather than assume the cache survives.
{{/params.high_availability}}

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-elasticache-valkey/operator.md
