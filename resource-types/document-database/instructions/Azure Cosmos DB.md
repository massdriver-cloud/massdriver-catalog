# Import an Azure Cosmos DB Account

```bash
az cosmosdb show --name <ACCOUNT> --resource-group <GROUP> \
  --query "{id:id, name:name, endpoint:documentEndpoint}"
az cosmosdb keys list --name <ACCOUNT> --resource-group <GROUP>
```

| Field | Source |
|---|---|
| `id` | The `id` field of the account. |
| `auth.endpoint` | The document endpoint. |
| `auth.primary_key` | The primary master key. |
| `auth.read_only_key` | The primary read only key. |

## Warning

The primary key grants full rights on every database in the account. Give an
application the read only key when it does not write.
