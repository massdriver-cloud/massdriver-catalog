# Azure Function App — Operator Guide

## Overview

This bundle provisions an Azure Function App with all supporting infrastructure: App Service Plan, Storage Account, Application Insights, optional Private Endpoints, and optional Recovery Services Vault backup. It outputs an `acd/azure-function-app` artifact with the hostname, managed identity, and telemetry connection details downstream bundles and CI/CD pipelines need.

## Resources Provisioned

| Resource | Purpose |
|---|---|
| Resource Group | Logical container |
| Storage Account | Functions runtime state (host keys, triggers, file shares) |
| Application Insights | Telemetry, tracing, and live metrics |
| App Service Plan | Hosting plan (ElasticPremium, PremiumV3, or Standard) |
| Linux Function App | Serverless compute with managed identity |
| Private Endpoints | Optional — lock down Function App and Storage from public internet |
| Recovery Services Vault | Optional — daily file share backup with configurable retention |

## Deploying Source Code

This bundle provisions **infrastructure only**. Function code is deployed separately via CI/CD. The bundle sets `WEBSITE_RUN_FROM_PACKAGE=1`, which means code is deployed as a zip package.

### Deployment Methods

**Azure Functions Core Tools** (local dev / simple CI):
```bash
func azure functionapp publish <app-name>
```

**GitHub Actions**:
```yaml
- uses: Azure/functions-action@v1
  with:
    app-name: ${{ steps.artifact.outputs.name }}
    package: ./output
```

**Azure DevOps**:
```yaml
- task: AzureFunctionApp@2
  inputs:
    azureSubscription: '<service-connection>'
    appType: 'functionAppLinux'
    appName: '<app-name>'
    package: '$(Pipeline.Workspace)/drop'
```

**Zip deploy via CLI**:
```bash
az functionapp deployment source config-zip \
  --resource-group <rg-name> \
  --name <app-name> \
  --src ./package.zip
```

The artifact exports `name` and `resource_group_name` for use in CI/CD pipelines. The `principal_id` (managed identity) can be used to grant the Function App access to other Azure resources without storing credentials.

## Hosting Plan Selection

| Tier | SKU | Best For | VNet Integration | Min Instances |
|---|---|---|---|---|
| **ElasticPremium** | EP1/EP2/EP3 | Production serverless with auto-scale | Yes | 1 (elastic) |
| **PremiumV3** | P1v3/P2v3/P3v3 | Dedicated compute, predictable billing | Yes | Per plan |
| **Standard** | S1/S2/S3 | Budget, low-traffic workloads | Limited | Per plan |

ElasticPremium is recommended for production — it supports VNet integration, private endpoints, and scales to zero warm instances while keeping at least one pre-warmed.

## Private Endpoints

When enabled, Private Endpoints place the Function App and/or Storage Account on a private subnet in the connected VNet. This:

- Removes public internet access to the resource
- Routes traffic through the VNet's private address space
- Requires a subnet with available IP addresses (the bundle uses `$md.enum` to let you pick from connected VNet subnets)

**Important**: The Storage Account private endpoint creates endpoints for blob, file, queue, and table sub-resources. DNS resolution must be configured (Azure Private DNS Zones) for the Function App to reach its storage over the private network.

## Compliance Notes

- **Runtime language is immutable** — changing from Python to Node (or vice versa) after deployment is destructive
- **Managed identity** is always enabled (CKV_AZURE_71) — use it for Key Vault, Storage, and SQL access instead of connection strings
- **HTTPS only** is enforced (CKV_AZURE_221)
- **TLS 1.2 minimum** (CKV_AZURE_155)
- **FTP disabled** — use zip deploy or Kudu only
- **Checkov skips** are documented in `.checkov.yml` with rationale for each

## Artifact Data

The `acd/azure-function-app` artifact exports:

| Field | Sensitive | Description |
|---|---|---|
| `id` | No | Function App resource ID |
| `name` | No | Function App name (use in CI/CD deploy commands) |
| `resource_group_name` | No | Resource group (use in CI/CD deploy commands) |
| `location` | No | Azure region |
| `default_hostname` | No | HTTPS endpoint (e.g., `my-fn.azurewebsites.net`) |
| `storage_account_name` | No | Backing storage account name |
| `app_insights_instrumentation_key` | Yes | App Insights key (legacy — prefer connection string) |
| `app_insights_connection_string` | Yes | App Insights connection string |
| `principal_id` | No | Managed identity object ID — use for IAM role assignments |
