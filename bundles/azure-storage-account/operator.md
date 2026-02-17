# Azure Storage Account Operations

## Overview

This bundle deploys an Azure Storage Account with a blob container for storing objects.

## Resources Created

- **Resource Group**: Container for all resources
- **Storage Account**: Standard LRS with TLS 1.2 minimum
- **Blob Container**: Private container for object storage

## Accessing Storage

### Azure Portal

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to Storage Accounts
3. Find: `{{name_prefix}}`
4. Navigate to Containers > `{{container_name}}`

### Azure CLI

```bash
# List blobs
az storage blob list \
  --account-name {{storage_account_name}} \
  --container-name {{container_name}} \
  --output table

# Upload a file
az storage blob upload \
  --account-name {{storage_account_name}} \
  --container-name {{container_name}} \
  --name myfile.txt \
  --file ./myfile.txt

# Download a file
az storage blob download \
  --account-name {{storage_account_name}} \
  --container-name {{container_name}} \
  --name myfile.txt \
  --file ./downloaded.txt
```

## Troubleshooting

### Permission Denied
Ensure the service principal has Storage Blob Data Contributor role on the storage account.

### Container Not Found
Verify the container name matches: `{{container_name}}`
