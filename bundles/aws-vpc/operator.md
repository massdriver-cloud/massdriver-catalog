# AWS VPC Operations Guide

## Overview

This bundle provisions an AWS VPC with public and private subnets, NAT Gateway for outbound internet access, and VPC Flow Logs for network monitoring.

## Resources Created

| Resource | Purpose |
|----------|---------|
| VPC | Isolated network for workloads |
| Public Subnets | For NAT Gateway, load balancers, bastion hosts |
| Private Subnets | For databases, containers, internal services |
| Internet Gateway | Internet access for public subnets |
| NAT Gateway | Outbound internet for private subnets |
| Route Tables | Traffic routing for public/private subnets |
| VPC Flow Logs | Network traffic logging to CloudWatch |

## Configuration

### Region
The region where all networking resources are deployed: **{{params.region}}**

### CIDR Range
- **VPC CIDR:** {{params.cidr}}

### Availability Zones
Resources are deployed across **{{params.availability_zones}}** availability zones for high availability.

## Troubleshooting

### Private resources can't reach the internet
1. Verify NAT Gateway is in a public subnet
2. Check route table associations for private subnets
3. Ensure route table has 0.0.0.0/0 -> NAT Gateway route
4. Check NAT Gateway state in AWS Console

### VPC Flow Logs not appearing
1. Verify IAM role permissions for CloudWatch Logs
2. Check CloudWatch Log Group exists
3. Flow logs may take a few minutes to appear

### Cross-AZ connectivity issues
1. Verify security groups allow traffic within VPC CIDR
2. Check NACL rules (default allows all)
3. Verify route tables are correctly associated

## Monitoring

### VPC Flow Logs
View in CloudWatch Logs:
```
/aws/vpc/{{artifact "vpc" "data.id"}}/flow-logs
```

### NAT Gateway Metrics
Monitor in CloudWatch:
- `BytesOutToDestination` - Outbound data volume
- `BytesOutToSource` - Response data volume
- `ErrorPortAllocation` - Port exhaustion indicator

## Scaling Considerations

- **NAT Gateway:** Single NAT per VPC. For HA, deploy NAT per AZ
- **Subnet sizing:** /20 subnets provide 4,091 usable IPs each
- **VPC Endpoints:** Add endpoints for high-traffic AWS services to reduce NAT costs

## Related Bundles

This VPC is typically used with:
- `aws-aurora-postgres` - PostgreSQL database in private subnets
- `aws-app-runner` - Serverless containers with VPC connector
