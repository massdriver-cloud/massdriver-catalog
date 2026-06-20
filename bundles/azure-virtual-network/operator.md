# Azure Virtual Network — Operator Guide

## Overview

This bundle provisions an Azure Virtual Network (VNet) with configurable subnets, NSGs, optional DDoS protection, and optional peering into a Virtual WAN hub. It outputs an `acd/azure-virtual-network` artifact consumed by downstream bundles.

## Resources Provisioned

| Resource | Purpose |
|---|---|
| Resource Group | Logical container for all VNet resources |
| Virtual Network | Layer-3 address space |
| Subnets | Logical network segmentation |
| Network Security Groups | One NSG per subnet (default-allow rules; add custom rules via Azure Policy or separate bundles) |
| NSG Associations | Binds each NSG to its subnet (CKV2_AZURE_31 compliance) |
| DDoS Protection Plan | Optional — Standard tier, additional cost |
| Virtual Hub Connection | Optional — peers VNet into a connected Virtual WAN hub |

## Virtual WAN Integration

The VNet has an **optional** connection slot for `acd/azure-virtual-wan`. When connected:

- The VNet is automatically peered into the Virtual WAN hub via `azurerm_virtual_hub_connection`
- Internet security is enabled on the connection (routes internet traffic through the hub firewall if configured)
- No additional configuration is needed from the developer

**Typical topology**: A network team manages the Virtual WAN bundle and shares it to projects as an environment default. Developers create VNets in their projects and draw a connection to the shared WAN — peering happens automatically.

## Sizing Guidance

| Environment | Address Space | Subnets | DDoS |
|---|---|---|---|
| Development | `/16` (65k addresses) | 1–2 subnets with `/24` blocks | Disabled |
| Production | `/14` or larger | Separate subnets for app, data, private endpoints, management | Enabled |

## Subnet Planning

Plan subnets based on workload isolation:

- **app** — Application tier (Function Apps, App Services, AKS)
- **data** — Data services (SQL MI, Cosmos DB, Redis)
- **private-endpoints** — Private Endpoints for PaaS services
- **management** — Bastion hosts, jump boxes, monitoring agents

Enable **service endpoints** on subnets that need direct access to Azure PaaS services (e.g., `Microsoft.Storage`, `Microsoft.Sql`, `Microsoft.KeyVault`).

## Compliance Notes

- **NSGs**: Every subnet gets an NSG with default Azure rules. Add custom deny/allow rules via Azure Policy or dedicated NSG bundles.
- **DDoS Protection**: Enable for PCI-DSS, HIPAA, and similar compliance regimes. Additional cost (~$2,944/month per plan, covers up to 100 VNets).
- **Network Watcher**: Azure auto-provisions one per subscription per region. Flow logs require a separate Storage Account and are configured outside this bundle.

## Artifact Data

The `acd/azure-virtual-network` artifact exports:

| Field | Description | Example |
|---|---|---|
| `id` | VNet resource ID | `/subscriptions/.../virtualNetworks/my-vnet` |
| `resource_group_name` | Resource group name | `my-prefix-rg` |
| `location` | Azure region | `eastus` |
| `cidr` | Address space | `10.0.0.0/16` |
| `subnets[].id` | Subnet resource ID | `/subscriptions/.../subnets/app` |
| `subnets[].name` | Subnet name | `app` |
| `subnets[].cidr` | Subnet CIDR | `10.0.0.0/24` |

## Downstream Bundles

Bundles that consume `acd/azure-virtual-network`:

- **azure-function-app** — Deploys into the VNet, uses subnets for private endpoints
- **azure-kubernetes-service** — AKS with VNet-integrated node pools
- **azure-sql-managed-instance** — SQL MI deployed into a delegated subnet
