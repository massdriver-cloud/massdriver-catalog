# GCP Subnetwork Operations Guide

## Overview

This bundle provisions a GCP VPC network with a regional subnetwork, Cloud NAT for egress, VPC Access Connector for serverless workloads, and Private Services Access for managed services like Cloud SQL.

## Resources Created

| Resource | Purpose |
|----------|---------|
| VPC Network | Isolated network for workloads |
| Subnetwork | Regional subnet with configurable CIDR |
| Cloud Router | Regional router for NAT gateway |
| Cloud NAT | Outbound internet access for private resources |
| VPC Access Connector | Allows Cloud Run/Functions to access VPC resources |
| Private Services Access | Peering for managed services (Cloud SQL, Memorystore) |
| Firewall Rule | Allows internal VPC traffic |

## Configuration

### Region
The region where all networking resources are deployed: **{{params.region}}**

### CIDR Ranges
- **Subnet CIDR:** {{params.cidr}}
- **Private Services CIDR:** {{params.private_services_cidr}}

## Troubleshooting

### Cloud Run can't connect to Cloud SQL
1. Verify the VPC Access Connector is healthy in GCP Console
2. Ensure Cloud SQL is using the Private Services Access range
3. Check that the firewall rule allows traffic from the connector IP range

### NAT not working
1. Check Cloud NAT logs in Cloud Logging
2. Verify the Cloud Router is in the correct region
3. Ensure instances are in the correct subnetwork

### Private Services Access issues
1. Verify the peering connection is active: `gcloud services vpc-peerings list --network={{artifact "subnetwork" "data.infrastructure.vpc_network_name"}}`
2. Check that the reserved IP range doesn't overlap with existing subnets

## Monitoring

### VPC Flow Logs
Flow logs are enabled with 5-second intervals. View in Cloud Logging:
```
resource.type="gce_subnetwork"
logName="projects/PROJECT_ID/logs/compute.googleapis.com%2Fvpc_flows"
```

### NAT Logs
```
resource.type="nat_gateway"
```

## Scaling Considerations

- **VPC Access Connector:** Scales automatically but has throughput limits. For high-throughput workloads, consider Direct VPC Egress
- **Cloud NAT:** Automatically allocates ports. Monitor port exhaustion in Cloud Monitoring
- **Private Services CIDR:** Size appropriately for expected managed services (/16 recommended)

## Related Bundles

This network is typically used with:
- `gcp-cloudsql-postgres` - PostgreSQL database using Private Services Access
- `gcp-cloud-run` - Serverless applications using VPC Access Connector
