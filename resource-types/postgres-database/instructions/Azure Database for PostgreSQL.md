# Import an Azure Database for PostgreSQL

Use these steps to register a server that you created outside of Massdriver.

## Find the values

```bash
az postgres flexible-server show \
  --resource-group <RESOURCE_GROUP> \
  --name <SERVER_NAME> \
  --query "{id:id, hostname:fullyQualifiedDomainName, version:version}"
```

## Map the values

| Field | Source |
|---|---|
| `id` | The `id` field of the server. |
| `auth.hostname` | The fully qualified domain name of the server. |
| `auth.port` | `5432`. |
| `auth.database` | The name of the database that the application uses. |
| `auth.username` | The application user. Do not use the administrator. |
| `auth.password` | The password of that user. |
| `policies` | One entry per access level that you permit. |

## Warning

Create a separate user for each application. Do not share the administrator
account. The administrator can drop every database on the server.
