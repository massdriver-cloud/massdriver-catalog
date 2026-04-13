# Azure Virtual Network — Operator Guide

## Overview

This bundle provisions an Azure Virtual Network (VNet) with configurable subnets, optional DDoS protection, and a Network Watcher for diagnostics enablement. It outputs an `acd/azure-virtual-network` artifact consumed by downstream bundles (VWAN, Function App, AKS, etc.).

## Resources Provisioned

| Resource | Purpose |
|---|---|
| Resource Group | Logical container for all VNet resources |
| Virtual Network | Layer-3 address space |
| Subnets | Logical network segmentation |
| Network Watcher | Enables flow log and diagnostics capabilities |
| DDoS Protection Plan | Optional — Standard tier, additional cost |

## Sizing Guidance

- **Development**: `/16` address space, 1-2 subnets with `/24` blocks
- **Production**: `/14` or larger to allow room for growth; separate subnets for app tier, data tier, private endpoints, and management

## Compliance Notes

- DDoS Protection Standard is exposed as a configurable param. Enable in production for PCI-DSS, HIPAA, and similar workloads.
- Network Watcher is always provisioned to enable flow log capabilities.
- Flow logs themselves require a Storage Account and are configured outside this bundle (or via Azure Policy).

## Downstream Connections

Bundles that can connect to `acd/azure-virtual-network`:
- `azure-virtual-wan` (peers the VNet into a Virtual Hub)
- `azure-function-app` (deploys into a delegated subnet via VNet Integration)
- `azure-kubernetes-service`
- `azure-sql-managed-instance`
