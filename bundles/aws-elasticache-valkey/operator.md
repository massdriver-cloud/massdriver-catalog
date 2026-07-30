---
templating: mustache
---

# Cache Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Host | `{{artifacts.cache.auth.hostname}}` |
| Port | `{{artifacts.cache.auth.port}}` |
| Engine | `{{artifacts.cache.engine}}` `{{artifacts.cache.version}}` |
| High availability | `{{params.high_availability}}` |

---

## Active alarms — what they mean

### Evictions climbing

The cache is out of memory and dropping keys before they'd naturally expire — sessions or cached data disappearing under load.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache --metric-name Evictions \
  --dimensions Name=ReplicationGroupId,Value={{artifacts.cache.id}} \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Sum
```

Either size up `node_size`, or check whether something is caching data with no TTL that should have one.

### Connections maxed out

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache --metric-name CurrConnections \
  --dimensions Name=ReplicationGroupId,Value={{artifacts.cache.id}} \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Maximum
```

Usually a connection-pooling bug on the app side (new client per request instead of a shared pool).

---

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

---

## Disaster recovery

{{#params.high_availability}}
This cache has automatic failover — losing the primary node promotes the replica within seconds, no manual action needed. Verify afterward with `INFO replication`.
{{/params.high_availability}}
{{^params.high_availability}}
**No standby node.** Losing this node means every session and cached value it held is gone — apps need to handle a cold cache gracefully (re-authenticate, re-fetch), not assume the cache survives.
{{/params.high_availability}}

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-elasticache-valkey/operator.md
