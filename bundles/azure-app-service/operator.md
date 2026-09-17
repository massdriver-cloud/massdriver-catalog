# Azure App Service Runbook

{{#resources.application}}
| Field | Value |
|---|---|
| Name | `{{resources.application.data.name}}` |
| URL | {{resources.application.data.service_url}} |
{{/resources.application}}

## The application returns 503

**Diagnosis.** The container did not start, or it does not listen on the
declared port.

**Fix.** Read the container log.

```bash
az webapp log tail \
  --name <APP_NAME> \
  --resource-group <RESOURCE_GROUP>
```

Check that the container listens on the port in `WEBSITES_PORT`.

## The first request after an idle period is slow

**Diagnosis.** Always On is off, so Azure unloaded the application.

**Fix.** Turn on Always On. A Basic plan or larger supports it.

## A deployment fails with a subnet error

**Diagnosis.** The network holds no subnet with the App Service delegation, or
another plan already uses that subnet.

**Fix.** Add a delegated subnet to the network.

## The application cannot reach the database

**Diagnosis.** Outbound traffic does not enter the network.

**Fix.** Check that `vnet_route_all_enabled` is on, and that the subnet belongs
to the same network as the database.

```bash
az webapp show \
  --name <APP_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --query "virtualNetworkSubnetId"
```

## Warning: a plan change restarts every application on the plan

Azure moves the plan to new hardware. Every application on it restarts.
