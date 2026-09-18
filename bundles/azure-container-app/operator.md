---
templating: mustache
---

# Container App Runbook

## Health check

{{#resources.application}}
```bash
curl -sS -o /dev/null -w "%{http_code}\n" {{resources.application.health_check_url}}
```

```bash
az containerapp revision list \
  --name {{resources.application.name}} \
  --resource-group {{resources.application.name}} \
  --query "[].{revision:name, active:properties.active, replicas:properties.replicas}" \
  --output table
```
{{/resources.application}}

## The application does not start

The image is wrong, the container exits, or the health check fails.

{{#resources.application}}
1. Read the logs of the running revision.
   ```bash
   az containerapp logs show \
     --name {{resources.application.name}} \
     --resource-group {{resources.application.name}} \
     --follow
   ```
2. Confirm that the container listens on port {{params.port}}.
3. Confirm that the path {{params.health_check_path}} answers 200.
{{/resources.application}}

## A deployment fails on the processor and memory pair

Azure accepts one memory size per processor share: 0.25 with 0.5Gi, 0.5 with
1Gi, 1.0 with 2Gi, 2.0 with 4Gi. Correct the pair in the form, then deploy.

## A deployment fails on the subnet

The network holds no subnet with the Container Apps delegation, or the subnet is
smaller than /23. Add a subnet of /23 or larger with that delegation, then
deploy again.

## The application cannot read the storage container

The role assignment is missing, or Azure has not applied it yet.

{{#dependencies.bucket}}
```bash
az role assignment list \
  --scope {{dependencies.bucket.id}} \
  --query "[].{principal:principalId, role:roleDefinitionName}" \
  --output table
```
{{/dependencies.bucket}}

Azure needs up to five minutes to apply a new role. Restart the revision after
that.

## The application cannot reach the database

{{#dependencies.database}}
The database answers inside the network only. Confirm that this application and
the database sit in the same network, then resolve the name from inside a
running revision.

```bash
az containerapp exec \
  --name {{resources.application.name}} \
  --resource-group {{resources.application.name}} \
  --command "nslookup {{dependencies.database.auth.hostname}}"
```
{{/dependencies.database}}

## Roll back a bad release

Set the image to the previous tag and deploy. Massdriver keeps every deployment,
so the old value is in the history of this instance.

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
