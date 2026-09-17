# Azure Virtual Network

This bundle creates a resource group, a virtual network, and the subnets inside it.

Each PaaS service gets its own subnet. The `delegation` field gives a subnet to
one Azure service. Azure then lets that service inject its own network interfaces.

## What it produces

A `virtual-network` resource. Any bundle that needs a network consumes it.

## Fields that you cannot change

- **Region.** Azure cannot move a network.
- **Network CIDR.** Azure destroys and recreates a network when this range changes.

Massdriver locks both fields after the first deployment.

## Delegation options

| Option | Azure service |
|---|---|
| None | No delegation. Use this subnet for virtual machines and private endpoints. |
| Container Apps | `Microsoft.App/environments` |
| App Service and Functions | `Microsoft.Web/serverFarms` |
| Database for PostgreSQL | `Microsoft.DBforPostgreSQL/flexibleServers` |
