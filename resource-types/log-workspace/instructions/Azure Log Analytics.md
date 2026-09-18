# Import an Azure Log Analytics Workspace

Use these steps to register a workspace that you created outside of Massdriver.

## Find the values

```bash
az monitor log-analytics workspace show \
  --resource-group <RESOURCE_GROUP> \
  --workspace-name <WORKSPACE_NAME> \
  --query "{id:id, name:name, region:location, retention_days:retentionInDays}"
```

## Map the values

| Field | Source |
|---|---|
| `id` | The `id` field of the workspace. |
| `name` | The `name` field of the workspace. |
| `region` | The `location` field of the workspace. |
| `retention_days` | The `retentionInDays` field of the workspace. |
