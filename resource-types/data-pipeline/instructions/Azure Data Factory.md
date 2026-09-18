# Import an Azure Data Factory

```bash
az datafactory show --name <FACTORY> --resource-group <GROUP> \
  --query "{id:id, name:name, region:location, principal_id:identity.principalId}"
```

| Field | Source |
|---|---|
| `id` | The `id` field of the factory. |
| `principal_id` | The principal of the managed identity. |
| `studio_url` | `https://adf.azure.com/en/home?factory=<id>`. |

## Warning

The identity of the factory needs a role on every source and every target. A
pipeline fails at run time when a role is missing, not at deployment time.
