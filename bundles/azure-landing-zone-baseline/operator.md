---
templating: mustache
---

# Landing Zone Baseline Runbook

## Health check

{{#resources.logs}}
```bash
az monitor log-analytics query \
  --workspace {{resources.logs.id}} \
  --analytics-query "AzureActivity | where TimeGenerated > ago(1h) | summarize count() by OperationNameValue" \
  --output table
```
{{/resources.logs}}

## The activity log holds no entries

The diagnostic setting is off, or the workspace is new. Azure needs about 15
minutes to write the first entry.

1. List the settings of the subscription.
   ```bash
   az monitor diagnostic-settings subscription list --output table
   ```
2. When the list is empty, turn on the activity log in the form and deploy.
3. Wait 15 minutes, then run the health check above.

## A deployment fails with `AuthorizationFailed`

The service principal cannot write at the subscription scope. The activity log
setting and the Defender plan both need it.

```bash
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "Security Admin" \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

## The Defender plan changes back and forth

Two instances of this bundle point at one subscription, and the settings are
subscription wide. Keep one instance per subscription, and decommission the
second one.

## The Standard plan starts a charge at once

Azure bills the Standard plan per resource per month, from the moment of the
change. Confirm the price list before you deploy that change.

## The log bill grows

{{#resources.logs}}
The workspace keeps an entry for {{resources.logs.retention_days}} days, and
Azure charges per gigabyte per month. Find the largest tables.

```bash
az monitor log-analytics query \
  --workspace {{resources.logs.id}} \
  --analytics-query "Usage | where TimeGenerated > ago(7d) | summarize Gb=sum(Quantity)/1000 by DataType | order by Gb desc" \
  --output table
```
{{/resources.logs}}

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
