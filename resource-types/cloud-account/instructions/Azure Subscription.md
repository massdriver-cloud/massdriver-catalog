# Import an Azure Subscription

Use these steps to register a subscription that exists already.

## Find the values

```bash
az account show --query "{id:id, name:name, tenant_id:tenantId}"
```

```bash
az account management-group entity list \
  --query "[?name=='<SUBSCRIPTION_ID>'].parent.name"
```

## Map the values

| Field | Source |
|---|---|
| `id` | The subscription ID. |
| `name` | The display name of the subscription. |
| `landing_zone_class` | `corporate` or `restricted`. You decide this. |
| `management_group` | The parent management group. |
| `tenant_id` | The directory that owns the subscription. |

## Warning

The class decides which bundles a project can use. Set `restricted` for any
subscription that accepts a short list of services only. Check the class with
the compliance owner before you change it.
