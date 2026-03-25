---
templating: mustache
---

# MariaDB RDS Operator Guide

## Package Information

**Slug:** `{{slug}}`

**Region:** `{{params.region}}`

**Engine Version:** MariaDB `{{params.engine_version}}`

**Instance Class:** `{{params.instance_class}}`

**Database Name:** `{{params.database_name}}`

**Multi-AZ:** `{{params.multi_az}}`

---

## Architecture

This bundle deploys a production-grade MariaDB instance on AWS RDS with:

- **Primary instance** with gp3 storage, encryption at rest (customer-managed KMS key)
- **Read replica** created when `multi_az = true` for read scale-out
- **Security group** restricting inbound to port 3306 from VPC CIDR only
- **Custom parameter group** with utf8mb4 character set
- **Secrets Manager** for credential storage

### Writer Connection

**Instance ID:** `{{artifacts.writer.id}}`

**Hostname:** `{{artifacts.writer.auth.hostname}}`

**Port:** `{{artifacts.writer.auth.port}}`

**Database:** `{{artifacts.writer.auth.database}}`

**Username:** `{{artifacts.writer.auth.username}}`

### Reader Connection

**Instance ID:** `{{artifacts.reader.id}}`

**Hostname:** `{{artifacts.reader.auth.hostname}}`

**Port:** `{{artifacts.reader.auth.port}}`

**Database:** `{{artifacts.reader.auth.database}}`

---

## Connecting to the Database

```bash
# Connect via mysql CLI (writer)
mysql -h {{artifacts.writer.auth.hostname}} \
      -u {{artifacts.writer.auth.username}} \
      -p \
      -P {{artifacts.writer.auth.port}} \
      {{artifacts.writer.auth.database}}

# Connect via mysql CLI (reader)
mysql -h {{artifacts.reader.auth.hostname}} \
      -u {{artifacts.reader.auth.username}} \
      -p \
      -P {{artifacts.reader.auth.port}} \
      {{artifacts.reader.auth.database}}

# Connection string format (writer)
mysql://{{artifacts.writer.auth.username}}:<password>@{{artifacts.writer.auth.hostname}}:{{artifacts.writer.auth.port}}/{{artifacts.writer.auth.database}}
```

---

## Common Operations

### Check Database Status

```bash
mysql -h {{artifacts.writer.auth.hostname}} -u {{artifacts.writer.auth.username}} -p \
  -e "SELECT version(), current_user(), @@hostname;"
```

### Check Database Size

```bash
mysql -h {{artifacts.writer.auth.hostname}} -u {{artifacts.writer.auth.username}} -p \
  -e "SELECT table_schema AS 'Database',
      ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
      FROM information_schema.tables
      WHERE table_schema = '{{artifacts.writer.auth.database}}'
      GROUP BY table_schema;"
```

### Show Active Connections

```bash
mysql -h {{artifacts.writer.auth.hostname}} -u {{artifacts.writer.auth.username}} -p \
  -e "SHOW PROCESSLIST;"
```

### Show Table Sizes

```bash
mysql -h {{artifacts.writer.auth.hostname}} -u {{artifacts.writer.auth.username}} -p \
  -e "SELECT table_name,
      ROUND(data_length / 1024 / 1024, 2) AS 'Data (MB)',
      ROUND(index_length / 1024 / 1024, 2) AS 'Index (MB)',
      table_rows AS 'Rows'
      FROM information_schema.tables
      WHERE table_schema = '{{artifacts.writer.auth.database}}'
      ORDER BY data_length + index_length DESC
      LIMIT 10;"
```

### Check Replication Status (Multi-AZ)

```bash
# On the reader endpoint
mysql -h {{artifacts.reader.auth.hostname}} -u {{artifacts.reader.auth.username}} -p \
  -e "SHOW SLAVE STATUS\G"
```

---

## Backup and Restore

### Create a Manual Backup

```bash
# Compressed backup
mysqldump -h {{artifacts.writer.auth.hostname}} \
  -u {{artifacts.writer.auth.username}} -p \
  --single-transaction --routines --triggers \
  {{artifacts.writer.auth.database}} | gzip > backup-$(date +%Y%m%d-%H%M%S).sql.gz
```

### Restore from Backup

```bash
gunzip < backup-20260325-120000.sql.gz | \
  mysql -h {{artifacts.writer.auth.hostname}} \
  -u {{artifacts.writer.auth.username}} -p \
  {{artifacts.writer.auth.database}}
```

---

## Monitoring

### CloudWatch Logs

This instance exports the following log groups:
- `/aws/rds/instance/<identifier>/audit`
- `/aws/rds/instance/<identifier>/error`
- `/aws/rds/instance/<identifier>/general`
- `/aws/rds/instance/<identifier>/slowquery`

### Check Slow Queries

```bash
# View slow query log via CloudWatch (replace <identifier> with RDS instance ID)
aws logs get-log-events \
  --log-group-name "/aws/rds/instance/<identifier>/slowquery" \
  --log-stream-name "<identifier>" \
  --limit 20 --region {{params.region}}
```

---

## Credentials

Master credentials are stored in AWS Secrets Manager. The secret ARN is broadcast through the artifact at `secrets_manager_arn`.

```bash
# Retrieve credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id "{{artifacts.writer.secrets_manager_arn}}" \
  --query SecretString --output text --region {{params.region}} | jq .
```

---

## Scaling

- **Vertical**: Change `instance_class` and redeploy
- **Storage**: Increase `allocated_storage` (storage can only scale up, never down)
- **Read scale-out**: Set `multi_az: true` to provision a read replica
- **Storage autoscaling**: Set `max_allocated_storage` above `allocated_storage`

## Upgrading Engine Version

The `engine_version` parameter is immutable. To upgrade:
1. Decommission the current deployment
2. Update the `engine_version` parameter
3. Redeploy

For automatic minor version upgrades, enable `auto_minor_version_upgrade` in maintenance settings.

---

## Troubleshooting

### Cannot Connect to Database

1. Verify the application is in a subnet within the VPC (`{{artifacts.writer.auth.hostname}}` is private)
2. Check the security group allows ingress on port 3306 from your subnet's CIDR
3. Verify credentials via Secrets Manager (see above)

### High Connection Count

```bash
mysql -h {{artifacts.writer.auth.hostname}} -u {{artifacts.writer.auth.username}} -p \
  -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';
      SHOW GLOBAL VARIABLES LIKE 'max_connections';"
```

### Storage Full

Check current storage usage in the RDS console or via CloudWatch metric `FreeStorageSpace`. If autoscaling is enabled (`max_allocated_storage > allocated_storage`), storage will grow automatically up to the ceiling.
