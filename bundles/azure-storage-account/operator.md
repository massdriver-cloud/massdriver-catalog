# Azure Storage Account Runbook

{{#resources.bucket}}
| Field | Value |
|---|---|
| Account | `{{resources.bucket.data.name}}` |
| Container | `{{resources.bucket.data.container}}` |
| Endpoint | `{{resources.bucket.data.endpoint}}` |
{{/resources.bucket}}

## An application gets `AuthorizationPermissionMismatch`

**Diagnosis.** The identity of the application holds no role on the container.
The bundle turns off the shared access key, so a connection string cannot work.

**Fix.** Assign the role that matches the selected policy.

```bash
az role assignment create \
  --assignee <PRINCIPAL_ID> \
  --role "Storage Blob Data Contributor" \
  --scope <STORAGE_ACCOUNT_ID>
```

## An application gets `AuthorizationFailure` or a connection timeout

**Diagnosis.** The traffic comes from outside the connected network. The account
denies it.

**Fix.** Check that the workload runs in a subnet of the connected network, and
that the subnet carries the `Microsoft.Storage` service endpoint.

```bash
az storage account show \
  --name <ACCOUNT_NAME> \
  --query "networkRuleSet.virtualNetworkRules"
```

## A deployment fails with `StorageAccountAlreadyTaken`

**Diagnosis.** The account name is global to Azure, and another tenant holds it.

**Fix.** Rename the instance. The bundle derives the account name from the
instance name.

## Warning: a change to the container name destroys the container

Massdriver marks the field immutable, so the form blocks the change. Azure
deletes a container and every object inside it when the name changes.

## Recover a deleted object

Azure keeps a deleted object for the retention period.

```bash
az storage blob undelete \
  --account-name <ACCOUNT_NAME> \
  --container-name <CONTAINER> \
  --name <BLOB> \
  --auth-mode login
```
