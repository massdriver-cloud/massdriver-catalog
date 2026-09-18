---
templating: mustache
---

# Virtual Network Runbook

## Health check

{{#resources.network}}
```bash
az network vnet show \
  --ids {{resources.network.id}} \
  --query "{state:provisioningState, cidr:addressSpace.addressPrefixes[0]}"
```

```bash
az network vnet subnet list \
  --resource-group {{resources.network.resource_group}} \
  --vnet-name {{resources.network.name}} \
  --query "[].{name:name, cidr:addressPrefix, free:!ipConfigurations}" \
  --output table
```
{{/resources.network}}

## A deployment fails with `InUseSubnetCannotBeDeleted`

A resource inside the subnet still exists, and Azure cannot delete a subnet that
holds a network interface.

{{#resources.network}}
1. Find the owner.
   ```bash
   az network vnet subnet show \
     --resource-group {{resources.network.resource_group}} \
     --vnet-name {{resources.network.name}} \
     --name <SUBNET> \
     --query "ipConfigurations[].id"
   ```
2. Delete that resource, or move it to another subnet.
3. Deploy again, and confirm that the subnet list above shows the new range.
{{/resources.network}}

## A deployment fails with `SubnetMissingRequiredDelegation`

The service needs a delegated subnet, and this subnet carries none.

1. Set the delegation of the subnet to the service that uses it.
2. Deploy again.
3. Confirm with the subnet list above.

## A deployment fails with `NetcfgInvalidSubnet`

A subnet range sits outside the network range, or two ranges overlap.

1. Correct the subnet ranges. Each one must sit inside the network range.
2. A Container Apps subnet needs /23 or larger, and the range must start on an
   even boundary. `10.30.0.0/23` is valid, and `10.30.1.0/23` is not.
3. Deploy again.

## A workload cannot reach a storage account or a SQL server

The subnet carries the service endpoint that those services need. Confirm it.

{{#resources.network}}
```bash
az network vnet subnet show \
  --resource-group {{resources.network.resource_group}} \
  --vnet-name {{resources.network.name}} \
  --name <SUBNET> \
  --query "serviceEndpoints[].service"
```
{{/resources.network}}

## The region or the range must change

Azure destroys the network and everything inside it. Massdriver marks both
fields immutable, so the form blocks the change. Build a second network, move
each workload, then decommission the first one.

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
