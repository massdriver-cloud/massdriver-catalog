# Azure Kubernetes Service

This bundle creates a cluster in the connected network. A chart bundle deploys
onto it.

## Network

The cluster uses the first subnet without a delegation. The Azure network plugin
gives every pod an address from that subnet, so the subnet needs free space.

Each node takes about 30 addresses. A `/24` subnet holds about 8 nodes.

## What it produces

A `kubernetes-cluster` resource. It carries the API server address and the
client certificate. Massdriver masks those fields, and it records every
download.

## Cost

| Item | Cost |
|---|---|
| Free tier control plane | No charge, and no uptime promise. |
| Standard tier control plane | About 73 dollars per month. |
| Nodes | The price of each virtual machine, per hour. |

## Fields that you cannot change

The private API server. Azure sets it at creation.
