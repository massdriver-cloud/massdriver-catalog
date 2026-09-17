# Azure Storage Account

This bundle creates a storage account and one blob container.

## What it produces

An `object-storage` resource. It carries the endpoint, the container name, and
three access policies.

## How an application gets access

The bundle turns off the shared access key, so no secret leaves it. An
application selects a policy, then assigns the matching Azure role to its own
managed identity.

| Policy | Azure role |
|---|---|
| Read | `Storage Blob Data Reader` |
| Read and write | `Storage Blob Data Contributor` |
| Full control | `Storage Blob Data Owner` |

## Network

The account denies all traffic, except traffic from the subnets of the
connected network. The subnets need the `Microsoft.Storage` service endpoint.
The `azure-virtual-network` bundle sets that endpoint on every subnet.

## Fields that you cannot change

- **Container name.** Azure cannot rename a container.
