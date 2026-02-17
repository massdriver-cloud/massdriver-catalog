# Azure Storage Account

Deploys an Azure Storage Account with a blob container for object storage.

## Features

- Standard LRS storage for cost-effective demos
- TLS 1.2 minimum for secure connections
- Blob versioning enabled
- Private container access

## Architecture

```
Azure Resource Group
└── Storage Account (Standard LRS)
    └── Blob Container (private)
```

## Connections

| Name | Type | Description |
|------|------|-------------|
| `azure_authentication` | `azure-service-principal` | Azure credentials for deployment |

## Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `eastus` | Azure region for resources |
| `container_name` | string | `demo` | Name of the blob container |

## Outputs

Produces a `bucket` artifact with:
- Storage account ID and name
- Blob endpoint URL
- Read/Write access policies for `$md.enum` binding
- Connection string for applications

## Changelog

### 0.0.1

- Initial release
- Azure Storage Account with blob container
- Read/Write policies for function app binding
