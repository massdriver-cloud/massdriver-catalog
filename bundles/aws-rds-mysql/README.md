# AWS RDS MySQL

Managed MySQL database on AWS RDS with automated backups, encryption, and monitoring.

## Features

- **Managed MySQL** - AWS handles patching, backups, and maintenance
- **Storage Encryption** - Data encrypted at rest using AWS KMS
- **Automated Backups** - Configurable backup window and retention
- **Enhanced Monitoring** - 60-second granularity CloudWatch metrics
- **Performance Insights** - Query-level performance analysis
- **CloudWatch Logs** - General, slow query, and error logs exported

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │              VPC                     │
                    │  ┌─────────────────────────────────┐│
                    │  │        Private Subnets          ││
                    │  │  ┌───────────────────────────┐  ││
                    │  │  │      RDS MySQL            │  ││
                    │  │  │   ┌─────────────────┐     │  ││
                    │  │  │   │  Primary (AZ-a) │     │  ││
                    │  │  │   │   Port 3306     │     │  ││
                    │  │  │   └─────────────────┘     │  ││
                    │  │  └───────────────────────────┘  ││
                    │  └─────────────────────────────────┘│
                    └─────────────────────────────────────┘
```

## Connections

| Name | Type | Description |
|------|------|-------------|
| `aws_authentication` | `aws-iam-role` | AWS credentials for deployment |
| `vpc` | `aws-vpc` | VPC with private subnets for RDS |

## Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `db_version` | string | `8.0` | MySQL version (5.7 or 8.0) |
| `instance_class` | string | `db.t3.micro` | RDS instance type |
| `allocated_storage` | integer | `20` | Storage size in GB |
| `database_name` | string | `mydb` | Default database name |
| `username` | string | `admin` | Master username |
| `backup_window` | string | `03:00-04:00` | Daily backup window (UTC) |
| `backup_retention_period` | integer | `7` | Backup retention days |
| `deletion_protection` | boolean | `true` | Prevent accidental deletion |
| `subnet_ids` | array | - | Private subnets for RDS |

## Outputs

- `database` - MySQL connection artifact with hostname, port, credentials

## Usage Notes

### Connecting to MySQL

The database artifact includes connection details:

```bash
mysql -h <hostname> -P 3306 -u <username> -p <database>
```

### SSL Connections

SSL is available for MySQL connections. Use the AWS RDS CA bundle:

```bash
mysql -h <hostname> -u <username> -p --ssl-ca=rds-ca-bundle.pem
```

### Version Support

- **MySQL 5.7** - Legacy applications
- **MySQL 8.0** - Recommended for new projects (default CTEs, window functions)

## Changelog

### 0.0.2

- Fix Performance Insights for db.t3.micro (disabled on unsupported instances)
- Add require_secure_transport parameter for SSL enforcement
- Add Checkov skip rules for security group egress and SNS encryption
- Skip IAM database auth - most apps don't support it (CKV_AWS_161)
- Add multi_az param for high availability (CKV_AWS_157)
- Skip deletion_protection/multi_az checks (user-configurable params)

### 0.0.1

- Initial release
- RDS MySQL with encryption at rest
- Automated backups and maintenance
- Enhanced monitoring and Performance Insights
- CloudWatch log exports (general, slowquery, error)
- High CPU utilization alarm
