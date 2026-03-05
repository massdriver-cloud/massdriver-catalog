# AWS Aurora PostgreSQL Serverless v2

Aurora PostgreSQL Serverless v2 database cluster for demo workloads. Provides automatic scaling based on workload with pay-per-second billing.

## Features

- Aurora PostgreSQL Serverless v2 with automatic scaling
- KMS encryption at rest with automatic key rotation
- VPC-only access with security groups
- Enhanced monitoring and Performance Insights
- Automated backups with configurable retention
- CloudWatch Logs integration
- Multi-AZ support for high availability

## Configuration

### Capacity

Aurora Serverless v2 uses Aurora Capacity Units (ACUs):
- 1 ACU = 2 GiB of memory and corresponding CPU/networking
- Minimum: 0.5 ACU (good for development)
- Maximum: Configure based on expected peak load
- Auto-scales between min and max based on workload

### Availability

- **Single-AZ**: One instance for development/testing
- **Multi-AZ**: Two instances across availability zones for production

### Backups

- Automated daily backups during preferred window
- Configurable retention period (1-35 days)
- Point-in-time recovery available within retention period

## Connections

This bundle requires:
- AWS IAM Role authentication
- AWS VPC with private subnets

## Outputs

Produces a `postgres` artifact with connection details for use by application bundles.
