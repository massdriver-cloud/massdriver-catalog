# GCP Cloud SQL PostgreSQL Operator Runbook

## Overview
This bundle provisions a fully managed PostgreSQL database instance on Google Cloud SQL with private networking, automated backups, and comprehensive logging for compliance.

## Architecture
- Private IP only (no public access)
- Connected to a GCP VPC subnetwork
- SSL/TLS encryption enforced for all connections
- Automated daily backups with configurable point-in-time recovery
- Optional high availability with regional replication

## Configuration

### Instance Sizing
- **db-f1-micro**: 0.6GB RAM, 1 shared vCPU - Dev/test only
- **db-g1-small**: 1.7GB RAM, 1 shared vCPU - Small workloads
- **db-custom-X-Y**: Custom CPU and memory configurations for production

### Storage
- Uses PD-SSD for performance
- Auto-resize enabled to prevent out-of-space issues
- Starts at minimum 10GB, can grow to 65TB

### Availability
- **Zonal**: Single zone deployment (lower cost)
- **Regional**: Multi-zone with automatic failover (production recommended)

### Backups
- Daily automated backups at 3:00 AM UTC
- Retains 7 backup snapshots
- Optional point-in-time recovery (PITR) with 7-day transaction log retention

## Security & Compliance

### Network Security
- Private IP only - no internet exposure
- Requires Cloud SQL Proxy or private service connection from workloads
- SSL mode set to `TRUSTED_CLIENT_CERTIFICATE_REQUIRED` for maximum security

### Logging
All database activity logging is enabled for audit compliance:
- Connection attempts (`log_connections`)
- Disconnections (`log_disconnections`)
- Checkpoint operations (`log_checkpoints`)
- Lock wait events (`log_lock_waits`)
- DDL statements (`log_statement=ddl`)
- Query duration (`log_duration`)
- Hostnames (`log_hostname`)
- pgAudit extension enabled (`cloudsql.enable_pgaudit`)

### Access Control
The bundle creates:
- Default database with user-specified name
- Admin user with generated 32-character alphanumeric password
- Three IAM policy levels: read-only, read-write, admin

## Connecting to the Database

### From Cloud Run (Recommended)
Connect Cloud Run services to the `database` artifact produced by this bundle. Cloud Run will automatically:
- Inject connection credentials as environment variables
- Configure Cloud SQL Proxy sidecar
- Establish encrypted connections

### Connection String Format
```
postgresql://<username>:<password>@<private_ip>:5432/<database_name>?sslmode=require
```

### Using Cloud SQL Proxy
For local development or compute instances without private network access:
```bash
cloud-sql-proxy <instance-connection-name>
```

## Monitoring

### Cloud SQL Insights
Query insights are enabled with:
- Top queries tracked
- Query plans captured (5 per minute)
- Application tags recorded
- Client addresses logged

### Key Metrics to Monitor
- CPU utilization
- Memory usage
- Disk utilization (watch for auto-resize events)
- Connection count
- Replication lag (if HA enabled)
- Backup success/failure

## Maintenance

### Maintenance Window
- Day: Sunday (7)
- Time: 4:00 AM local time
- Track: Stable (production-ready updates only)

### Version Upgrades
PostgreSQL version is **immutable** after creation. To upgrade:
1. Create a new instance with desired version
2. Use pg_dump/pg_restore or Cloud SQL replication
3. Cut over application traffic
4. Decommission old instance

## Common Operations

### Scaling Up
1. Update `tier` parameter to larger instance type
2. Deploy changes (requires ~5 minute restart)

### Enabling High Availability
1. Set `availability.high_availability = true`
2. Deploy changes (provisions standby replica)

### Restoring from Backup
Use GCP Console or gcloud:
```bash
gcloud sql backups list --instance=<instance-name>
gcloud sql backups restore <backup-id> --backup-instance=<instance-name>
```

### Point-in-Time Recovery
If enabled, restore to any timestamp:
```bash
gcloud sql instances clone <source> <target> --point-in-time='<timestamp>'
```

## Troubleshooting

### Cannot Connect
- Verify workload is on the same VPC network
- Check that private service connection is established
- Ensure Cloud SQL Proxy is configured correctly
- Verify firewall rules allow Cloud SQL traffic

### Slow Queries
- Review Query Insights in GCP Console
- Consider scaling to larger instance tier
- Analyze and optimize problematic queries
- Add appropriate indexes

### Disk Space Issues
- Auto-resize should handle growth automatically
- If disabled, manually increase `disk_size` parameter
- Monitor for rapid growth patterns

### Replication Lag (HA)
- Check network latency between zones
- Review write workload patterns
- Consider vertical scaling if CPU/IO bound

## Disaster Recovery

### Backup Strategy
- Automated daily backups retained for 7 days
- PITR enables recovery to specific point in time
- Test restore procedures regularly

### Cross-Region DR
For multi-region disaster recovery:
1. Create read replica in different region
2. Use Cloud SQL replication
3. Promote replica to standalone in DR scenario

## Cost Optimization

### Development Workloads
- Use db-f1-micro or db-g1-small
- Disable high availability
- Reduce backup retention
- Use smaller disk sizes

### Production Workloads
- Right-size instance tier based on actual usage
- Enable HA only if required (2x cost)
- Monitor and adjust disk size appropriately
- Use committed use discounts for predictable workloads

## Support & Documentation

- [Cloud SQL for PostgreSQL Documentation](https://cloud.google.com/sql/docs/postgres)
- [Cloud SQL Proxy Guide](https://cloud.google.com/sql/docs/postgres/sql-proxy)
- [Performance Best Practices](https://cloud.google.com/sql/docs/postgres/best-practices)
- [Security Best Practices](https://cloud.google.com/sql/docs/postgres/security-best-practices)
