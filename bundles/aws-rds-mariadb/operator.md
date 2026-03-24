# MariaDB RDS - Operator Guide

## Overview

This bundle deploys a production-grade MariaDB database on AWS RDS. It produces two
connection artifacts: a **writer** (primary instance) and a **reader** (read replica when
multi-AZ is enabled, or the primary endpoint when running in single-AZ mode).

## Architecture

- **Primary Instance**: `aws_db_instance.main` — always created. Uses gp3 storage with
  autoscaling, encrypted at rest with a customer-managed KMS key.
- **Read Replica**: `aws_db_instance.reader` — created only when `multi_az = true`. Points
  the `reader` artifact at a dedicated replica endpoint.
- **Security Group**: Restricts inbound access to port 3306 from within the VPC CIDR only.
- **Parameter Group**: Custom MariaDB parameter group with slow query logging, deadlock
  printing, and utf8mb4 character set.
- **KMS Key**: Dedicated CMK for RDS storage and Performance Insights encryption.

## Connection Details

### Writer Connection
- Endpoint: Primary RDS instance address
- Artifact field: `writer`
- Policies: `read-write`, `admin`

### Reader Connection
- Endpoint: Read replica address (multi-AZ) or primary address (single-AZ)
- Artifact field: `reader`
- Policies: `read-only`

## Secrets

The master password is stored in AWS SSM Parameter Store at:
```
/<name_prefix>/mariadb/master-password
```

## Compliance

- Encryption at rest: Enabled (CMK)
- Encryption in transit: Enforced via SSL/TLS (MariaDB default)
- Public accessibility: Disabled
- Audit logging: Enabled (CloudWatch Logs)
- IAM database authentication: Enabled
- Deletion protection: Configurable (enabled by default)

## Upgrading Engine Version

The `engine_version` parameter is marked `$md.immutable`. To upgrade:
1. Decommission the current deployment
2. Update the `engine_version` parameter
3. Re-deploy

For in-place minor version upgrades, enable `auto_minor_version_upgrade`.

## Scaling

- Vertical: Change `instance_class` and re-deploy
- Storage: Increase `allocated_storage` (storage can only scale up)
- Read scale-out: Enable `multi_az` to provision a read replica

## Troubleshooting

- Check CloudWatch Logs groups: `/aws/rds/instance/<identifier>/error` and `/slowquery`
- Enhanced monitoring metrics available in CloudWatch under `RDS` namespace when interval > 0
- Performance Insights dashboard available in RDS console when enabled
