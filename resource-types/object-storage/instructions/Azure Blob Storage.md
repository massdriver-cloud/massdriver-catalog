# Import an Azure Storage Account

Use these steps to register a storage account that you created outside of
Massdriver.

## Find the values

```bash
az storage account show \
  --name <ACCOUNT_NAME> \
  --query "{id:id, name:name, region:location, endpoint:primaryEndpoints.blob}"
```

## Map the values

| Field | Source |
|---|---|
| `id` | The `id` field of the account. |
| `name` | The `name` field of the account. |
| `container` | The name of the blob container that the application uses. |
| `endpoint` | The blob endpoint, plus the container name. |
| `region` | The `location` field of the account. |
| `account_id` | The subscription ID that holds the account. |
| `policies` | One entry per access level that you permit. |

## Warning

Give the application the lowest access level that it needs. A policy of
`read-write` cannot delete an object. Use `admin` only for a workload that
manages the container.
