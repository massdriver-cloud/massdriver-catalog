---
templating: mustache
---

# App Service Runbook

## Health check

{{#resources.application}}
```bash
curl -sS -o /dev/null -w "%{http_code}\n" {{resources.application.health_check_url}}
```
{{/resources.application}}

## The application returns 503

The container did not start, or it does not listen on the declared port.

{{#resources.application}}
1. Read the log stream.
   ```bash
   az webapp log tail --ids {{resources.application.deployment_id}}
   ```
2. Confirm that the container listens on port {{params.port}}. The bundle sets
   `WEBSITES_PORT` to that value.
3. Restart the application.
   ```bash
   az webapp restart --ids {{resources.application.deployment_id}}
   ```
{{/resources.application}}

## The first request after an idle period is slow

Always On is off, so Azure unloaded the application. Turn on Always On in the
form and deploy. A Basic plan or larger supports it.

## A deployment fails on the subnet

The network holds no subnet with the App Service delegation, or another plan
already uses that subnet. Add a delegated subnet, then deploy again.

## The application cannot reach the database or the storage account

All outbound traffic must enter the network.

{{#resources.application}}
```bash
az webapp show --ids {{resources.application.deployment_id}} \
  --query "{subnet:virtualNetworkSubnetId, routeAll:siteConfig.vnetRouteAllEnabled}"
```
{{/resources.application}}

The subnet must belong to the same network as the database.

## A plan change restarts every application on the plan

Azure moves the plan to new hardware, and every application on it restarts. Make
the change in a maintenance window.

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
