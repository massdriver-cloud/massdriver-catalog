# AWS Aurora PostgreSQL Operations Guide

## Overview

This bundle provisions an Aurora PostgreSQL Serverless v2 cluster with automatic scaling, encryption, enhanced monitoring, and automated backups.

## Resources Created

| Resource | Purpose |
|----------|---------|
| Aurora Cluster | PostgreSQL Serverless v2 cluster |
| Aurora Instance | Serverless v2 compute instance |
| DB Subnet Group | Private subnet placement |
| Security Group | VPC-only access control |
| KMS Key | Encryption at rest |
| IAM Role | Enhanced monitoring |

## Configuration

### Connection Details
- **Endpoint:** {{artifact "database" "data.auth.hostname"}}
- **Port:** 5432
- **Database:** {{params.database_name}}
- **Username:** {{params.username}}

### Capacity
- **Minimum ACUs:** {{params.capacity.min_capacity}}
- **Maximum ACUs:** {{params.capacity.max_capacity}}

ACU (Aurora Capacity Unit) = ~2 GB memory. Serverless v2 scales in 0.5 ACU increments.

## Troubleshooting

### Connection refused
1. Verify security group allows traffic from source CIDR
2. Check DB subnet group uses private subnets
3. Ensure source is within VPC or has VPC connectivity

### Slow queries
1. Check Performance Insights in AWS Console
2. Review `pg_stat_statements` for query analysis
3. Consider increasing max_capacity for more resources

### High latency during scaling
1. Serverless v2 scales incrementally (smooth)
2. Large capacity jumps may cause brief latency
3. Consider higher min_capacity for consistent performance

## Monitoring

### CloudWatch Metrics
Key metrics to monitor:
- `ServerlessDatabaseCapacity` - Current ACU usage
- `CPUUtilization` - CPU percentage
- `FreeableMemory` - Available memory
- `DatabaseConnections` - Active connections

### Performance Insights
Enabled by default. View in AWS Console:
- Top SQL queries by wait time
- Database load analysis
- Wait event analysis

### PostgreSQL Logs
Exported to CloudWatch Logs:
```
/aws/rds/cluster/{{artifact "database" "data.id"}}/postgresql
```

## Backup & Recovery

### Automated Backups
- Retention: {{params.backup.retention_days}} days
- Backup window: 03:00-04:00 UTC
- Point-in-time recovery available

### Manual Snapshots
```bash
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier {{artifact "database" "data.id"}} \
  --db-cluster-snapshot-identifier manual-snapshot-$(date +%Y%m%d)
```

## Scaling Considerations

- **Vertical:** Serverless v2 auto-scales between min/max ACUs
- **Read replicas:** Add reader instances for read scaling
- **Connection pooling:** Use RDS Proxy for high-connection workloads

## Related Bundles

This database is typically used with:
- `aws-vpc` - VPC with private subnets
- `aws-app-runner` - Serverless containers (via VPC connector)
