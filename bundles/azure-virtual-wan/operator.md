# Azure Virtual WAN — Operator Guide

## Overview

This bundle provisions an Azure Virtual WAN with a regional hub and optional VPN gateway for branch office connectivity. It outputs an `acd/azure-virtual-wan` artifact that VNet bundles consume to automatically peer into the hub.

## Resources Provisioned

| Resource | Purpose |
|---|---|
| Resource Group | Logical container for WAN resources |
| Virtual WAN | Global transit backbone |
| Virtual Hub | Regional routing hub with its own address space |
| VPN Gateway | Optional — S2S VPN for branch offices (additional cost) |

## Architecture

```
Branch Offices ──VPN──▶ [Virtual Hub] ◀── VNet (project A)
                              ▲
                              └── VNet (project B)
```

The Virtual WAN hub acts as a central routing point. VNets peer into the hub via the `azure-virtual-network` bundle's optional VWAN connection. Traffic between peered VNets routes through the hub automatically.

## WAN Type

| Type | Capabilities |
|---|---|
| **Basic** | Single hub, point-to-site VPN only |
| **Standard** | Multi-hub, VNet peering, ExpressRoute, S2S VPN, inter-hub routing |

Use **Standard** for production. Basic does not support VNet-to-VNet transit routing.

## VPN Gateway Sizing

Each scale unit provides ~500 Mbps aggregate throughput:

| Scale Units | Throughput | Use Case |
|---|---|---|
| 1 | 500 Mbps | Small branch office |
| 2 | 1 Gbps | Multiple branches |
| 4+ | 2+ Gbps | Enterprise branch connectivity |

## Operational Model

**Network team** manages this bundle:
1. Deploy the Virtual WAN in a shared project or at the org level
2. Share the `acd/azure-virtual-wan` artifact to target environments via environment defaults
3. Project teams connect their VNets to the shared WAN on the canvas

**Project teams** never configure the WAN directly — they just draw a connection from their VNet to the shared WAN artifact.

## Compliance Notes

- **WAN type is immutable** after creation. Changing from Basic to Standard requires a full redeploy.
- **Hub address prefix is immutable**. Choose a CIDR that won't overlap with any VNets you plan to peer.
- **Branch-to-branch traffic** is disabled by default. Enable it only if branches need direct communication without routing through a firewall.

## Artifact Data

The `acd/azure-virtual-wan` artifact exports:

| Field | Description |
|---|---|
| `id` | Virtual WAN resource ID |
| `resource_group_name` | Resource group name |
| `location` | Azure region |
| `virtual_hub_id` | Hub resource ID (used for VNet peering) |
| `virtual_hub_address_prefix` | Hub CIDR |
| `vpn_gateway_id` | VPN Gateway ID (only present when VPN is enabled) |
