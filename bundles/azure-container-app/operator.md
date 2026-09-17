# Azure Container App Runbook

{{#resources.application}}
| Field | Value |
|---|---|
| Name | `{{resources.application.data.name}}` |
| URL | {{resources.application.data.service_url}} |
| Revision | `{{resources.application.data.deployment_id}}` |
{{/resources.application}}

## The application does not start

**Diagnosis.** The image is wrong, the container exits, or the health check
fails.

**Fix.** Read the logs of the revision.

```bash
az containerapp logs show \
  --name <APP_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --follow
```

## A deployment fails with a subnet error

**Diagnosis.** The Container Apps subnet is smaller than /23, or it holds
another service.

**Fix.** Give the network a subnet of /23 or larger with the Container Apps
delegation.

## A deployment fails with an invalid processor and memory pair

**Diagnosis.** Azure accepts one memory size per processor share.

**Fix.** Use one of these pairs: 0.25 with 0.5Gi, 0.5 with 1Gi, 1.0 with 2Gi,
2.0 with 4Gi.

## The application cannot read the storage container

**Diagnosis.** The role assignment is missing, or it has not taken effect yet.
Azure needs up to five minutes to apply a new role.

**Fix.** Check the assignment.

```bash
az role assignment list \
  --assignee <PRINCIPAL_ID> \
  --scope <STORAGE_ACCOUNT_ID> \
  --output table
```

## The application cannot reach the database

**Diagnosis.** The database answers inside the network only. The application
must run in the same network.

**Fix.** Check that the network connection of both instances points at the same
virtual network.

## Roll back a bad release

Change the image tag to the previous version and deploy again. Massdriver keeps
the whole deployment history.
