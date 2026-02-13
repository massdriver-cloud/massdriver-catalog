---
templating: mustache
---

# RDS MySQL - Operator Guide

## Database Details

**Instance ID:** `{{md_metadata.name_prefix}}`
**MySQL Version:** `{{params.db_version}}`
**Instance Class:** `{{params.instance_class}}`
**Database Name:** `{{params.database_name}}`
**Region:** `{{connections.vpc.region}}`

---

## Connect to Database

### Using MySQL CLI

```bash
mysql -h {{artifacts.database.auth.hostname}} \
  -P {{artifacts.database.auth.port}} \
  -u {{artifacts.database.auth.username}} \
  -p{{artifacts.database.auth.password}} \
  {{artifacts.database.auth.database}}
```

### Connection String

```
mysql://{{artifacts.database.auth.username}}:{{artifacts.database.auth.password}}@{{artifacts.database.auth.hostname}}:{{artifacts.database.auth.port}}/{{artifacts.database.auth.database}}
```

---

## Common Operations

### Check Database Status

```sql
SHOW STATUS LIKE 'Uptime';
SHOW STATUS LIKE 'Connections';
SHOW STATUS LIKE 'Threads_connected';
```

### List Databases

```sql
SHOW DATABASES;
```

### Create a New Database

```sql
CREATE DATABASE new_database CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Create a User

```sql
CREATE USER 'app_user'@'%' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON {{params.database_name}}.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
```

---

## Monitoring

### View CloudWatch Logs

```bash
# Error logs
aws logs tail /aws/rds/instance/{{md_metadata.name_prefix}}/error --follow

# Slow query logs
aws logs tail /aws/rds/instance/{{md_metadata.name_prefix}}/slowquery --follow

# General logs
aws logs tail /aws/rds/instance/{{md_metadata.name_prefix}}/general --follow
```

### Check Instance Status

```bash
aws rds describe-db-instances \
  --db-instance-identifier {{md_metadata.name_prefix}} \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Storage:AllocatedStorage,Class:DBInstanceClass}'
```

### View Performance Insights

```bash
aws pi get-resource-metrics \
  --service-type RDS \
  --identifier db-$(aws rds describe-db-instances --db-instance-identifier {{md_metadata.name_prefix}} --query 'DBInstances[0].DbiResourceId' --output text) \
  --metric-queries '[{"Metric": "db.load.avg"}]' \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)
```

---

## Troubleshooting

### Connection Issues

Check security group allows connections:

```bash
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values={{md_metadata.name_prefix}}-rds-sg" \
  --query 'SecurityGroups[0].IpPermissions'
```

### Slow Queries

View slow query log:

```sql
-- In MySQL
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'long_query_time';
```

### Storage Space

Check allocated vs used storage:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value={{md_metadata.name_prefix}} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average
```

---

## Backup & Recovery

### View Automated Backups

```bash
aws rds describe-db-snapshots \
  --db-instance-identifier {{md_metadata.name_prefix}} \
  --snapshot-type automated
```

### Create Manual Snapshot

```bash
aws rds create-db-snapshot \
  --db-instance-identifier {{md_metadata.name_prefix}} \
  --db-snapshot-identifier {{md_metadata.name_prefix}}-manual-$(date +%Y%m%d)
```

### Export Data with mysqldump

```bash
mysqldump -h {{artifacts.database.auth.hostname}} \
  -u {{artifacts.database.auth.username}} \
  -p{{artifacts.database.auth.password}} \
  {{artifacts.database.auth.database}} > backup.sql
```

---

## Resource Limits

| Instance Class | vCPU | Memory | Max Connections |
|---------------|------|--------|-----------------|
| db.t3.micro | 2 | 1 GB | ~85 |
| db.t3.small | 2 | 2 GB | ~170 |
| db.t3.medium | 2 | 4 GB | ~340 |
| db.t3.large | 2 | 8 GB | ~680 |
| db.m5.large | 2 | 8 GB | ~680 |
| db.r5.large | 2 | 16 GB | ~1365 |
