# Import an Azure SQL Database

```bash
az sql db show --name <DATABASE> --server <SERVER> --resource-group <GROUP> \
  --query "{id:id, tier:sku.tier}"
az sql server show --name <SERVER> --resource-group <GROUP> \
  --query "{hostname:fullyQualifiedDomainName, username:administratorLogin}"
```

| Field | Source |
|---|---|
| `id` | The `id` field of the database. |
| `auth.hostname` | The fully qualified name of the server. |
| `auth.port` | `1433`. |
| `auth.database` | The name of the database. |
| `auth.username` | The administrator user. |
| `auth.password` | The password of that user. |

## Warning

Create a separate user for each application. The administrator can drop every
database on the server.
