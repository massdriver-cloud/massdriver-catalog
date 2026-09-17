# Azure Virtual Network Runbook

{{#resources.network}}
| Field | Value |
|---|---|
| Network | `{{resources.network.data.name}}` |
| Resource group | `{{resources.network.data.resource_group}}` |
| Region | `{{resources.network.data.region}}` |
| CIDR | `{{resources.network.data.cidr}}` |
{{/resources.network}}

## A deployment fails with `InvalidResourceLocation` or `InUseSubnetCannotBeDeleted`

**Diagnosis.** A resource inside the subnet still exists. Azure cannot delete a
subnet that holds a network interface.

**Fix.** Find the owner, then delete it first.

```bash
az network vnet subnet show \
  --resource-group <RESOURCE_GROUP> \
  --vnet-name <VNET_NAME> \
  --name <SUBNET_NAME> \
  --query "ipConfigurations[].id"
```

## A deployment fails with `SubnetMissingRequiredDelegation`

**Diagnosis.** The service needs a delegated subnet, and this subnet has none.

**Fix.** Set the `delegation` field of the subnet to the service that uses it.
Then deploy again.

## A deployment fails with `NetcfgInvalidSubnet`

**Diagnosis.** The subnet range sits outside the network range, or two subnets
overlap.

**Fix.** Correct the subnet CIDR values. Each range must sit inside the network
CIDR, and no two ranges may overlap.

## Warning: a change to the region or the CIDR destroys the network

Massdriver marks both fields immutable, so the form blocks the change. If you
must change one, you create a new network and move every workload to it.

## The service principal lacks permission

**Symptom.** The deployment fails with `AuthorizationFailed`.

**Fix.** Give the service principal the `Network Contributor` role on the
subscription, or on the resource group.

```bash
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "Network Contributor" \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```
