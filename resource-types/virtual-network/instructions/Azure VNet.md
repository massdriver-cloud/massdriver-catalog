# Import an Azure Virtual Network

Use these steps to register a VNet that you created outside of Massdriver.

## Find the values

Run this command. Replace the resource group and the network name.

```bash
az network vnet show \
  --resource-group <RESOURCE_GROUP> \
  --name <VNET_NAME> \
  --query "{id:id, name:name, cidr:addressSpace.addressPrefixes[0], region:location, resource_group:resourceGroup}"
```

Run this command to list the subnets.

```bash
az network vnet subnet list \
  --resource-group <RESOURCE_GROUP> \
  --vnet-name <VNET_NAME> \
  --query "[].{id:id, name:name, cidr:addressPrefix}"
```

## Map the values

| Field | Source |
|---|---|
| `id` | The `id` field of the VNet. |
| `name` | The `name` field of the VNet. |
| `cidr` | The first address prefix of the VNet. |
| `region` | The `location` field of the VNet. |
| `account_id` | The subscription ID that holds the VNet. |
| `resource_group` | The resource group that holds the VNet. |
| `subnets` | One entry per subnet. |

## Warning

Do not import a network that a Massdriver bundle already manages. Two owners of
one network cause a deployment conflict.
