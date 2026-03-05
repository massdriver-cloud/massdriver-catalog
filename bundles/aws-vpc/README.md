# aws-vpc

AWS VPC with public and private subnets for demo workloads.

## Features

- VPC with configurable CIDR block
- Public subnets across 2 availability zones for NAT Gateway and load balancers
- Private subnets across 2 availability zones for databases and containers
- Internet Gateway for public internet access
- NAT Gateway for private subnet outbound connectivity
- VPC Flow Logs for network monitoring and security analysis

## Architecture

The bundle creates a standard AWS VPC architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                   │
├──────────────────────────┬──────────────────────────────────┤
│   Public Subnets         │     Private Subnets              │
│                          │                                  │
│  ┌─────────────────┐     │    ┌─────────────────┐          │
│  │ us-east-1a      │     │    │ us-east-1a      │          │
│  │ 10.0.0.0/18     │     │    │ 10.0.128.0/18   │          │
│  │ - NAT Gateway   │────────▶ │ - Databases     │          │
│  │ - Load Balancer │     │    │ - Containers    │          │
│  └─────────────────┘     │    └─────────────────┘          │
│          │               │                                  │
│  ┌─────────────────┐     │    ┌─────────────────┐          │
│  │ us-east-1b      │     │    │ us-east-1b      │          │
│  │ 10.0.64.0/18    │     │    │ 10.0.192.0/18   │          │
│  └─────────────────┘     │    └─────────────────┘          │
│          │               │                                  │
│  Internet Gateway        │                                  │
└──────────┼───────────────┴──────────────────────────────────┘
           │
        Internet
```

## Use Cases

- Development and testing environments
- Demo applications
- Simple web applications
- Proof-of-concept workloads

## Compliance

This bundle includes security best practices:
- VPC Flow Logs enabled by default
- Private subnets for workloads
- NAT Gateway for secure outbound access
- DNS resolution enabled
