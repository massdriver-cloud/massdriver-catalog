# AWS VPC Bundle - Operator Runbook

## Bundle Overview

The `aws-vpc` bundle creates a production-ready AWS VPC with:
- VPC with configurable CIDR block
- Public subnets (2 AZs) for NAT Gateway and load balancers
- Private subnets (2 AZs) for databases and containers
- Internet Gateway for public internet access
- NAT Gateway for private subnet outbound connectivity
- Optional VPC Flow Logs for network monitoring

## Prerequisites

### AWS Credentials Setup

This bundle requires an AWS IAM Role artifact to be configured as an environment default.

**To set up AWS credentials:**

1. Navigate to the environment in the Massdriver UI
2. Go to Settings → Credentials
3. Add AWS IAM Role credential:
   - **Type**: aws-iam-role
   - **ARN**: `arn:aws:iam::YOUR_ACCOUNT_ID:role/ROLE_NAME`
   - **External ID**: (Optional) External ID from IAM role trust policy

4. Set as environment default for the credentials group

**Creating the IAM Role (if not already created):**

```bash
# Create the role with Massdriver trust policy
aws iam create-role \
  --role-name MassdriverProvisioner \
  --description="Massdriver Cloud Provisioning Role" \
  --assume-role-policy-document='{
    "Version":"2012-10-17",
    "Statement":[{
      "Sid":"MassdriverCloudProvisioner",
      "Effect":"Allow",
      "Principal":{"AWS":["308878630280"]},
      "Action":"sts:AssumeRole",
      "Condition":{"StringEquals":{"sts:ExternalId":"YOUR_EXTERNAL_ID"}}
    }]
  }'

# Attach administrator access
aws iam attach-role-policy \
  --role-name MassdriverProvisioner \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

## Configuration Parameters

### region
- **Type**: string
- **Description**: AWS region for VPC resources
- **Default**: us-east-1
- **Options**: us-east-1, us-east-2, us-west-1, us-west-2, eu-west-1, eu-central-1, ap-southeast-1

### cidr
- **Type**: string
- **Description**: IP range for the VPC
- **Default**: 10.0.0.0/16
- **Pattern**: CIDR notation (e.g., 10.0.0.0/16)

The VPC CIDR will be automatically divided into 4 equal subnets:
- 2 public subnets (first 2 quarters)
- 2 private subnets (last 2 quarters)

For example, with `10.0.0.0/16`:
- Public subnet 1: `10.0.0.0/18` (us-east-1a)
- Public subnet 2: `10.0.64.0/18` (us-east-1b)
- Private subnet 1: `10.0.128.0/18` (us-east-1a)
- Private subnet 2: `10.0.192.0/18` (us-east-1b)

### enable_flow_logs
- **Type**: boolean
- **Description**: Enable VPC Flow Logs for network monitoring
- **Default**: true

## Artifacts Produced

### vpc (aws-vpc)

The bundle produces an `aws-vpc` artifact containing:

```json
{
  "vpc_id": "vpc-xxxxx",
  "region": "us-east-1",
  "cidr": "10.0.0.0/16",
  "public_subnets": [
    {
      "subnet_id": "subnet-xxxxx",
      "availability_zone": "us-east-1a",
      "cidr": "10.0.0.0/18"
    },
    {
      "subnet_id": "subnet-yyyyy",
      "availability_zone": "us-east-1b",
      "cidr": "10.0.64.0/18"
    }
  ],
  "private_subnets": [
    {
      "subnet_id": "subnet-zzzzz",
      "availability_zone": "us-east-1a",
      "cidr": "10.0.128.0/18"
    },
    {
      "subnet_id": "subnet-aaaaa",
      "availability_zone": "us-east-1b",
      "cidr": "10.0.192.0/18"
    }
  ]
}
```

This artifact can be connected to other AWS bundles that require VPC networking (RDS, ECS, App Runner, etc.).

## Deployment

### Initial Deployment

```bash
# Configure the package
mass pkg cfg <project>-<env>-<manifest> --params=/path/to/params.json

# Deploy
mass pkg deploy <project>-<env>-<manifest> -m "Initial VPC deployment"
```

### Monitoring Deployment

```bash
# Watch deployment logs
mass logs <deployment-id>

# Check package status
mass pkg get <project>-<env>-<manifest>
```

## Troubleshooting

### Missing AWS Credentials Error

**Error**: `Required property aws_authentication was not present.`

**Solution**: Set up AWS IAM Role credentials as described in Prerequisites section.

### Insufficient IAM Permissions

**Error**: Access denied errors during deployment

**Solution**: Ensure the IAM role has the necessary permissions:
- EC2 full access (VPC, Subnets, IGW, NAT, Route Tables)
- CloudWatch Logs (for VPC Flow Logs)
- IAM role creation (for Flow Logs service role)

### CIDR Conflicts

**Error**: CIDR block conflicts with existing resources

**Solution**: Choose a non-overlapping CIDR range for your VPC.

### AZ Availability

**Error**: Requested AZs not available

**Solution**: The bundle automatically selects the first 2 available AZs in the region. This should work in all standard AWS regions.

## Decommissioning

```bash
# Decommission the VPC
mass pkg deploy <project>-<env>-<manifest> --action decommission -m "Removing VPC"
```

**Warning**: Ensure no resources are running in the VPC before decommissioning. Dependent resources should be destroyed first.

## Security & Compliance

### VPC Flow Logs

When enabled, VPC Flow Logs capture:
- Accepted traffic
- Rejected traffic
- All traffic metadata

Logs are stored in CloudWatch Logs with 7-day retention (configurable in code).

### Network Isolation

- **Public subnets**: Auto-assign public IPs, route to Internet Gateway
- **Private subnets**: No public IPs, route to NAT Gateway for outbound only

### Best Practices

1. **Enable Flow Logs**: Always enable for security monitoring and troubleshooting
2. **Use appropriate CIDR sizing**: Plan for growth but avoid unnecessarily large ranges
3. **Multi-AZ deployment**: Resources span 2 AZs for availability
4. **Private by default**: Deploy workloads in private subnets when possible

## Resources Created

- 1 VPC
- 2 Public Subnets (across 2 AZs)
- 2 Private Subnets (across 2 AZs)
- 1 Internet Gateway
- 1 NAT Gateway
- 1 Elastic IP (for NAT)
- 2 Route Tables (public, private)
- 4 Route Table Associations
- 1 CloudWatch Log Group (if flow logs enabled)
- 1 IAM Role for Flow Logs (if enabled)
- 1 VPC Flow Log (if enabled)

## Cost Considerations

Estimated monthly costs (us-east-1):
- **NAT Gateway**: ~$32.40 (24/7 operation) + data processing
- **Elastic IP**: Free when attached to running NAT Gateway
- **VPC, Subnets, IGW, Route Tables**: Free
- **VPC Flow Logs**: ~$0.50 per GB ingested + CloudWatch storage
- **CloudWatch Logs**: First 5GB free, then $0.50/GB

**Total**: ~$35-50/month depending on traffic volume

## Next Steps After Deployment

1. Connect the VPC artifact to workload bundles (RDS, ECS, App Runner)
2. Configure security groups for application traffic
3. Set up VPC peering if connecting to other VPCs
4. Configure VPC endpoints for AWS services if needed
5. Review Flow Logs for baseline network activity
