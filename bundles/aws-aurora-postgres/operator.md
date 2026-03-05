# AWS Aurora PostgreSQL Bundle - Operator Runbook

## Bundle Overview

The `aws-aurora-postgres` bundle creates a production-ready Aurora PostgreSQL Serverless v2 cluster with:
- Aurora Serverless v2 for automatic scaling
- Encryption at rest using KMS
- Enhanced Monitoring for performance insights
- Automatic backups
- VPC-isolated deployment

## Prerequisites

### Connections Required

- **aws_authentication** (required): AWS IAM Role artifact (environment default)
- **vpc** (required): aws-vpc artifact providing networking

## Configuration Parameters

### region
- **Type**: string
- **Description**: AWS region for Aurora cluster
- **Default**: us-east-1

### engine_version
- **Type**: string
- **Description**: PostgreSQL major version
- **Default**: 16.4
- **Options**: 13.15, 14.12, 15.7, 16.4

### database_name
- **Type**: string
- **Description**: Name of the default database
- **Default**: app

### username
- **Type**: string
- **Description**: Admin username
- **Default**: postgres

### capacity
- **min_acu**: Minimum Aurora Capacity Units (0.5 to 128)
- **max_acu**: Maximum Aurora Capacity Units (0.5 to 128)

### availability
- **multi_az**: Enable multi-AZ deployment for high availability

### backup
- **retention_days**: Days to retain automated backups (1-35)

## Artifacts Produced

### database (postgres)

The bundle produces a `postgres` artifact containing:

```json
{
  "auth": {
    "hostname": "cluster-endpoint.us-east-1.rds.amazonaws.com",
    "port": 5432,
    "database": "app",
    "username": "postgres",
    "password": "<generated>"
  }
}
```

## Deployment

### Initial Deployment

```bash
# Configure the package
mass pkg cfg <project>-<env>-<manifest> --params=/path/to/params.json

# Deploy
mass pkg deploy <project>-<env>-<manifest> -m "Initial Aurora deployment"
```

## Troubleshooting

### Connection Timeout

**Error**: Cannot connect to database

**Solution**:
- Ensure the security group allows traffic from your VPC CIDR
- Verify the client is in a VPC with connectivity to private subnets
- Check security group rules in AWS Console

### Capacity Issues

**Error**: Too many connections or slow queries

**Solution**: Increase `max_acu` to allow scaling to higher capacity

## Resources Created

- 1 Aurora PostgreSQL Serverless v2 Cluster
- 1-2 Aurora Instances (based on multi_az setting)
- 1 DB Subnet Group
- 1 Security Group
- 1 KMS Key + Alias
- 1 IAM Role for Enhanced Monitoring

## Cost Considerations

Estimated monthly costs (us-east-1):
- **Aurora Serverless v2**: ~$0.12/ACU-hour (scales based on usage)
- **Storage**: $0.10 per GB-month
- **I/O**: $0.20 per million requests
- **Backup Storage**: Free up to 100% of cluster storage

**Minimum**: ~$50/month (0.5 ACU, minimal storage)
