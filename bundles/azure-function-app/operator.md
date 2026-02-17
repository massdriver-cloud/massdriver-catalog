# Azure Function App Operations

## Overview

This bundle deploys a Node.js Azure Function App that provides a REST API for reading and writing to Azure Blob Storage.

## API Reference

Base URL: `{{artifacts.application.service_url}}/api`

### Health Check

```bash
curl {{artifacts.application.service_url}}/api/health
```

**Response:**
```json
{
  "status": "healthy",
  "container": "demo",
  "policy": "write",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### List Blobs

```bash
curl {{artifacts.application.service_url}}/api/blobs
```

**Response:**
```json
{
  "blobs": [
    {
      "name": "example.txt",
      "size": 42,
      "lastModified": "2024-01-15T10:30:00.000Z"
    }
  ],
  "count": 1
}
```

### Get Blob Content

```bash
curl {{artifacts.application.service_url}}/api/blob/example.txt
```

**Response:**
```json
{
  "name": "example.txt",
  "content": "Hello, World!"
}
```

### Create/Update Blob

```bash
curl -X POST {{artifacts.application.service_url}}/api/blob/example.txt \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello from Massdriver!"}'
```

**Response:**
```json
{
  "message": "Blob created",
  "name": "example.txt",
  "url": "https://storageaccount.blob.core.windows.net/demo/example.txt"
}
```

### Delete Blob

```bash
curl -X DELETE {{artifacts.application.service_url}}/api/blob/example.txt
```

**Response:**
```json
{
  "message": "Blob deleted",
  "name": "example.txt"
}
```

## Quick Demo Script

Run this to test the full read/write cycle:

```bash
BASE_URL="{{artifacts.application.service_url}}/api"

# Check health
echo "=== Health Check ==="
curl -s "$BASE_URL/health" | jq

# Create a blob
echo -e "\n=== Create Blob ==="
curl -s -X POST "$BASE_URL/blob/demo.json" \
  -H "Content-Type: application/json" \
  -d '{"greeting": "Hello from Massdriver!", "timestamp": "'$(date -Iseconds)'"}' | jq

# List blobs
echo -e "\n=== List Blobs ==="
curl -s "$BASE_URL/blobs" | jq

# Read the blob
echo -e "\n=== Read Blob ==="
curl -s "$BASE_URL/blob/demo.json" | jq

# Delete the blob
echo -e "\n=== Delete Blob ==="
curl -s -X DELETE "$BASE_URL/blob/demo.json" | jq

# Confirm deletion
echo -e "\n=== List Blobs (empty) ==="
curl -s "$BASE_URL/blobs" | jq
```

## Access Policies

The function respects the storage policy selected during configuration:

| Policy | Read | Write | Delete |
|--------|------|-------|--------|
| `read` | Yes | No | No |
| `write` | Yes | Yes | Yes |

If an operation is denied, you'll receive a 403 response:

```json
{
  "error": "Write access denied by policy"
}
```

## Troubleshooting

### Function Not Responding
1. Check Azure Portal > Function App > Functions to verify deployment
2. Check Application Insights for errors (if enabled)
3. Verify the function is running: `curl {{artifacts.application.service_url}}/api/health`

### Storage Errors
1. Verify the storage account connection in Configuration > Application settings
2. Check that `BLOB_STORAGE_CONNECTION_STRING` is set correctly
3. Ensure the container exists in the storage account

### Permission Denied
The function's access level is controlled by the `storage_policy` parameter:
- **Read**: Can list and read blobs
- **Write**: Can list, read, create, update, and delete blobs

To change access level, update the bundle configuration in Massdriver.

## Azure Portal Access

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to Function Apps
3. Find: `{{artifacts.application.name}}`
4. View logs: Functions > api > Monitor
