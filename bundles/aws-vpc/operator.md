---
templating: mustache
---

# AWS VPC Operator Guide

## Package Information

**Slug:** `{{slug}}`

**Region:** `{{params.region}}`

**CIDR Block:** `{{params.cidr}}`

**NAT Gateway:** `{{params.create_nat_gateway}}`

---

## Architecture

This bundle deploys a VPC with public and private subnets across 2 availability zones.

- **Public subnets** have an Internet Gateway route and auto-assign public IPs
- **Private subnets** route through a NAT Gateway (when enabled) for outbound-only internet access
- **Default security group** is locked down with no ingress/egress rules (CKV2_AWS_12)

## Network Details

**VPC ID:** `{{artifacts.aws_vpc.id}}`

**VPC CIDR:** `{{artifacts.aws_vpc.cidr}}`

### Subnets

| Subnet ID | CIDR | Type |
|-----------|------|------|
{{#artifacts.aws_vpc.subnets}}
| `{{id}}` | `{{cidr}}` | {{type}} |
{{/artifacts.aws_vpc.subnets}}

---

## Common Operations

### Verify VPC Connectivity

```bash
# List all subnets in the VPC
aws ec2 describe-subnets --filters "Name=vpc-id,Values={{artifacts.aws_vpc.id}}" \
  --query "Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]" \
  --output table --region {{params.region}}
```

### Check Route Tables

```bash
# Show route tables associated with this VPC
aws ec2 describe-route-tables --filters "Name=vpc-id,Values={{artifacts.aws_vpc.id}}" \
  --query "RouteTables[*].{ID:RouteTableId,Routes:Routes}" \
  --output json --region {{params.region}}
```

### Check NAT Gateway Status

```bash
# List NAT gateways in this VPC
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values={{artifacts.aws_vpc.id}}" \
  --query "NatGateways[*].[NatGatewayId,State,SubnetId]" \
  --output table --region {{params.region}}
```

### Inspect Security Groups

```bash
# List all security groups in the VPC
aws ec2 describe-security-groups --filters "Name=vpc-id,Values={{artifacts.aws_vpc.id}}" \
  --query "SecurityGroups[*].[GroupId,GroupName,Description]" \
  --output table --region {{params.region}}
```

---

## Troubleshooting

### Private Subnets Have No Internet Access

If `create_nat_gateway` is `false`, private subnets have no outbound internet route. Resources in private subnets (RDS, ElastiCache) can still communicate within the VPC but cannot reach external endpoints.

To restore outbound access, set `create_nat_gateway: true` and redeploy.

### Subnet IP Exhaustion

Each subnet uses a `/24` CIDR (251 usable IPs). Monitor with:

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values={{artifacts.aws_vpc.id}}" \
  --query "Subnets[*].[SubnetId,AvailableIpAddressCount,CidrBlock]" \
  --output table --region {{params.region}}
```

### DNS Resolution Issues

This VPC has DNS support and DNS hostnames enabled. If resources cannot resolve hostnames:

```bash
aws ec2 describe-vpc-attribute --vpc-id {{artifacts.aws_vpc.id}} \
  --attribute enableDnsSupport --region {{params.region}}

aws ec2 describe-vpc-attribute --vpc-id {{artifacts.aws_vpc.id}} \
  --attribute enableDnsHostnames --region {{params.region}}
```

---

## Scaling

- **More AZs**: Modify the bundle to use additional availability zones (currently uses 2)
- **CIDR expansion**: The CIDR is immutable after creation. To change it, decommission and redeploy
- **Additional subnets**: Add subnet resources to the Terraform for specialized workloads
