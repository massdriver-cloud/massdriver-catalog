---
templating: mustache
---

# Azure Storage Account Operations

> **Templating**: This runbook supports mustache templating.
> **Available context**: `slug`, `params`, `connections.<name>`, `artifacts.<name>`

## Package Information

**Slug:** `{{slug}}`

### Configuration

**Region:** `{{params.region}}`

**Container Name:** `{{params.container_name}}`

---

## Resources Created

- **Resource Group**: `{{artifacts.storage.data.resource_group_name}}`
- **Storage Account**: `{{artifacts.storage.name}}` (Standard LRS with TLS 1.2 minimum)
- **Blob Container**: `{{artifacts.storage.data.container_name}}`

## Storage Details

**Storage Account ID:** `{{artifacts.storage.id}}`

**Storage Account Name:** `{{artifacts.storage.name}}`

**Primary Blob Endpoint:** `{{artifacts.storage.endpoint}}`

**Container Name:** `{{artifacts.storage.data.container_name}}`

---

## Accessing Storage

### Azure Portal

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to Storage Accounts
3. Find: `{{artifacts.storage.name}}`
4. Navigate to Containers > `{{artifacts.storage.data.container_name}}`

### Azure CLI

```bash
# List blobs
az storage blob list \
  --account-name {{artifacts.storage.name}} \
  --container-name {{artifacts.storage.data.container_name}} \
  --connection-string "{{artifacts.storage.data.connection_string}}" \
  --output table

# Upload a file
az storage blob upload \
  --account-name {{artifacts.storage.name}} \
  --container-name {{artifacts.storage.data.container_name}} \
  --connection-string "{{artifacts.storage.data.connection_string}}" \
  --name myfile.txt \
  --file ./myfile.txt

# Download a file
az storage blob download \
  --account-name {{artifacts.storage.name}} \
  --container-name {{artifacts.storage.data.container_name}} \
  --connection-string "{{artifacts.storage.data.connection_string}}" \
  --name myfile.txt \
  --file ./downloaded.txt

# Delete a file
az storage blob delete \
  --account-name {{artifacts.storage.name}} \
  --container-name {{artifacts.storage.data.container_name}} \
  --connection-string "{{artifacts.storage.data.connection_string}}" \
  --name myfile.txt
```

### Using Connection String

The connection string can be used with Azure SDKs:

```python
# Python example
from azure.storage.blob import BlobServiceClient

connection_string = "{{artifacts.storage.data.connection_string}}"
blob_service = BlobServiceClient.from_connection_string(connection_string)
container = blob_service.get_container_client("{{artifacts.storage.data.container_name}}")

# List blobs
for blob in container.list_blobs():
    print(blob.name)
```

```javascript
// Node.js example
const { BlobServiceClient } = require("@azure/storage-blob");

const connectionString = "{{artifacts.storage.data.connection_string}}";
const blobService = BlobServiceClient.fromConnectionString(connectionString);
const container = blobService.getContainerClient("{{artifacts.storage.data.container_name}}");

// List blobs
for await (const blob of container.listBlobsFlat()) {
  console.log(blob.name);
}
```

---

## Troubleshooting

### Permission Denied

Ensure the service principal has Storage Blob Data Contributor role on the storage account.

The storage account name is: `{{artifacts.storage.name}}`

### Container Not Found

Verify the container name matches: `{{artifacts.storage.data.container_name}}`

### Connection Issues

Check that:
1. The storage account exists in resource group: `{{artifacts.storage.data.resource_group_name}}`
2. Network rules allow your IP address
3. The connection string is valid

---

**Ready to customize?** [Edit this runbook](https://github.com/massdriver-cloud/massdriver-catalog/tree/main/bundles/azure-storage-account/operator.md)
