# Azure Function App

Deploys a Node.js Azure Function App that provides a REST API for interacting with Azure Blob Storage.

## Features

- Node.js 20 runtime on Linux consumption plan
- HTTP-triggered API with anonymous access
- Read/Write blob operations
- Policy-based access control via `$md.enum`
- Auto-generated HTTPS URL

## Architecture

```
Azure Resource Group
├── Service Plan (Consumption Y1)
├── Function App (Node.js 20)
│   └── api function (HTTP trigger)
└── Storage Account (function runtime)
    └── Deployments Container

Connected Storage Account (from bundle)
└── Demo Container
```

## Connections

| Name | Type | Description |
|------|------|-------------|
| `azure_authentication` | `azure-service-principal` | Azure credentials for deployment |
| `storage` | `bucket` | Storage account for blob operations |

## Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `region` | string | `eastus` | Azure region for resources |
| `storage_policy` | string | - | Access policy (Read/Write) from storage artifact |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/blobs` | List all blobs |
| GET | `/api/blob/{name}` | Get blob content |
| POST | `/api/blob/{name}` | Create/update blob |
| DELETE | `/api/blob/{name}` | Delete blob |

## Quick Test

```bash
# Health check
curl https://<function-url>/api/health

# Create a blob
curl -X POST https://<function-url>/api/blob/test.txt \
  -d "Hello World"

# Read it back
curl https://<function-url>/api/blob/test.txt
```

## Changelog

### 0.0.1

- Initial release
- Node.js 20 Azure Function App
- REST API for blob storage operations
- Policy-based access control
