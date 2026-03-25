---
templating: mustache
---

# ElastiCache Redis Operator Guide

## Package Information

**Slug:** `{{slug}}`

**Region:** `{{params.region}}`

**Use Case:** `{{params.use_case}}`

**Engine Version:** Redis `{{params.engine_version}}`

**Node Type:** `{{params.node_type}}`

**Cache Nodes:** `{{params.num_cache_clusters}}`

**Automatic Failover:** `{{params.automatic_failover_enabled}}`

**Multi-AZ:** `{{params.multi_az_enabled}}`

---

## Architecture

This bundle deploys an ElastiCache Redis replication group with use-case-specific tuning:

- **Caching**: `allkeys-lru` eviction, no snapshots, single node OK
- **Session Storage**: `noeviction` policy, snapshots enabled, multi-AZ recommended
- **Pub/Sub**: `allkeys-lru` eviction, keyspace notifications enabled

### Infrastructure Components

- **Replication group** with configurable node count (1 = single node, 2+ = primary + replicas)
- **KMS key** for encryption at rest (customer-managed)
- **Security group** restricting inbound to port `{{params.port}}` from VPC CIDR only
- **Custom parameter group** tuned for the selected use case
- **Secrets Manager** for auth token storage (when auth is enabled)

---

## Connection Details

**Replication Group ID:** `{{artifacts.redis.id}}`

**Hostname:** `{{artifacts.redis.auth.hostname}}`

**Port:** `{{artifacts.redis.auth.port}}`

**Auth Token Required:** `{{params.auth_token_enabled}}`

**TLS Enabled:** `{{params.transit_encryption_enabled}}`

---

## Connecting to Redis

### redis-cli

```bash
# Without auth token
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}}

# With auth token
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} -a '<auth-token>'
```

### Connection String

```
redis{{#params.transit_encryption_enabled}}s{{/params.transit_encryption_enabled}}://{{artifacts.redis.auth.hostname}}:{{artifacts.redis.auth.port}}
```

---

## Common Operations

### Check Cluster Info

```bash
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} INFO server
```

### Check Memory Usage

```bash
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} INFO memory
```

### Check Connected Clients

```bash
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} INFO clients
```

### Check Key Count and DB Stats

```bash
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} INFO keyspace
```

### Check Replication Status

```bash
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} INFO replication
```

### Flush All Keys (Use With Caution)

```bash
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} FLUSHALL
```

### Monitor Commands in Real-Time

```bash
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} MONITOR
```

---

## Monitoring

### CloudWatch Metrics

Key metrics to watch:

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `CPUUtilization` | CPU usage | > 80% sustained |
| `DatabaseMemoryUsagePercentage` | Memory used vs available | > 90% |
| `CurrConnections` | Active client connections | Varies by node type |
| `Evictions` | Keys evicted (caching use case only) | Sudden spikes |
| `ReplicationLag` | Replica lag in seconds | > 1s sustained |
| `EngineCPUUtilization` | Redis process CPU | > 90% |

### Check via AWS CLI

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name DatabaseMemoryUsagePercentage \
  --dimensions Name=CacheClusterId,Value={{artifacts.redis.id}}-001 \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Average \
  --region {{params.region}}
```

---

## Scaling

- **Vertical**: Change `node_type` and redeploy (causes brief downtime)
- **Horizontal**: Increase `num_cache_clusters` to add read replicas
- **Failover**: Set `automatic_failover_enabled: true` with `num_cache_clusters >= 2`

## Troubleshooting

### Cannot Connect to Redis

1. Verify the client is in a subnet within the VPC
2. Check the security group allows ingress on port `{{params.port}}` from your subnet's CIDR
3. If TLS is enabled, ensure the client supports TLS connections
4. If auth token is enabled, verify the token via Secrets Manager

### High Memory Usage

```bash
# Check memory breakdown
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} MEMORY STATS

# Find largest keys
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} --bigkeys
```

### Slow Commands

```bash
# Check slow log
redis-cli -h {{artifacts.redis.auth.hostname}} -p {{artifacts.redis.auth.port}} {{#params.transit_encryption_enabled}}--tls{{/params.transit_encryption_enabled}} SLOWLOG GET 10
```

### Evictions (Caching Use Case)

Evictions are expected with `allkeys-lru` policy. If evictions are too high, scale up the node type or add replicas to distribute read load.

For session storage (`noeviction` policy), the cluster will return errors when memory is full instead of evicting keys. Scale up before hitting the memory limit.
