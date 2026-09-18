---
templating: mustache
---

# Fivetran Agent Runbook

## Health check

```bash
kubectl get pods -n {{params.namespace}} -l app.kubernetes.io/name={{params.chart.name}}
```

## The agent does not appear in the Fivetran dashboard

The token is wrong, or the pod cannot reach Fivetran.

1. Read the logs.
   ```bash
   kubectl logs -n {{params.namespace}} -l app.kubernetes.io/name={{params.chart.name}} --tail=100
   ```
2. Confirm that the cluster reaches the internet through its outbound address.
3. When the log shows a rejected token, correct the token in the Fivetran Account
   resource, then deploy this instance again.

## The pod starts, and nothing happens

Helm ignored the value keys, because the names do not match the chart. Helm
reports no error for a wrong key.

```bash
helm get values -n {{params.namespace}} <RELEASE>
```

Compare each key with the chart documentation, then correct `chart/values.jq`
and publish the bundle again.

## The agent cannot reach the database

{{#dependencies.database}}
```bash
kubectl run -n {{params.namespace}} netcheck --rm -it --image=busybox --restart=Never \
  -- nc -zv {{dependencies.database.auth.hostname}} {{dependencies.database.auth.port}}
```

The cluster and the database must sit in the same network.
{{/dependencies.database}}

## Rotate the token

Set a new value in the Fivetran Account resource, then deploy every agent that
uses it. Fivetran keeps the old token until you delete the agent in its
dashboard.

## Escalation

- **Team**: Data Platform
- **Slack**: #platform-support
