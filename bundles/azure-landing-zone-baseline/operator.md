# Landing Zone Baseline Runbook

{{#resources.logs}}
| Field | Value |
|---|---|
| Workspace | `{{resources.logs.data.name}}` |
| Region | `{{resources.logs.data.region}}` |
| Retention | `{{resources.logs.data.retention_days}}` days |
{{/resources.logs}}

## The activity log holds no entries

**Diagnosis.** The diagnostic setting is off, or the workspace is new. Azure
needs about 15 minutes for the first entry.

**Fix.** Check the setting.

```bash
az monitor diagnostic-settings subscription list --output table
```

## A deployment fails with `AuthorizationFailed`

**Diagnosis.** The service principal cannot write at the subscription scope.
The activity log setting and the Defender plan both need that scope.

**Fix.** Give the service principal the `Contributor` role and the
`Security Admin` role on the subscription.

## Warning: the Standard plan starts a charge at once

Azure bills the Defender Standard plan per resource per month, from the moment
of the change. Read the price list before you select it.

## Two instances fight over the settings

**Symptom.** The Defender plan changes back and forth between two deployments.

**Diagnosis.** Two instances of this bundle point at one subscription. The
settings are subscription wide.

**Fix.** Keep one instance per subscription. Decommission the second one.

## Query the logs

```bash
az monitor log-analytics query \
  --workspace <WORKSPACE_ID> \
  --analytics-query "AzureActivity | where TimeGenerated > ago(1h) | take 20"
```
