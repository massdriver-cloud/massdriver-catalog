---
templating: mustache
---

# Storage Account Runbook

## Health check

{{#resources.bucket}}
```bash
az storage account show \
  --ids {{resources.bucket.id}} \
  --query "{state:provisioningState, tls:minimumTlsVersion, sharedKey:allowSharedKeyAccess}"
```
{{/resources.bucket}}

## An application gets `AuthorizationPermissionMismatch`

The identity of the application holds no role on the container. This account
turns off the shared access key, so a connection string cannot work.

{{#resources.bucket}}
1. Assign the role that matches the policy that the application selected.
   ```bash
   az role assignment create \
     --assignee <PRINCIPAL_ID> \
     --role "Storage Blob Data Contributor" \
     --scope {{resources.bucket.id}}
   ```
2. Wait up to five minutes. Azure needs that time to apply a new role.
3. Verify.
   ```bash
   az role assignment list --assignee <PRINCIPAL_ID> --scope {{resources.bucket.id}} --output table
   ```
{{/resources.bucket}}

## An application gets a timeout or `AuthorizationFailure`

The traffic comes from outside the connected network, and the account denies it.

{{#resources.bucket}}
1. Read the rules that the account holds now.
   ```bash
   az storage account show --ids {{resources.bucket.id}} \
     --query "networkRuleSet.{action:defaultAction, subnets:virtualNetworkRules[].id}"
   ```
2. Confirm that the workload runs in one of those subnets.
3. Confirm that the subnet carries the `Microsoft.Storage` service endpoint.
{{/resources.bucket}}

## A deployment fails with `StorageAccountAlreadyTaken`

The account name is global to Azure, and another tenant holds it. Rename the
instance. The bundle builds the account name from the instance name.

## Recover a deleted object

{{#resources.bucket}}
Azure keeps a deleted object for {{params.retention_days}} days.

```bash
az storage blob undelete \
  --account-name {{resources.bucket.name}} \
  --container-name {{resources.bucket.container}} \
  --name <BLOB> \
  --auth-mode login
```
{{/resources.bucket}}

## The container name must change

Azure deletes the container and every object inside it. Massdriver marks the
field immutable, so the form blocks the change. Create a second instance, copy
the objects with `azcopy`, then decommission the first one.

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
