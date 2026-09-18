---
templating: mustache
---

# Subscription Factory Runbook

## Health check

{{#resources.account}}
```bash
az account show --subscription {{resources.account.id}} \
  --query "{name:name, state:state, tenant:tenantId}"
```

```bash
az account management-group entity list \
  --query "[?name=='{{resources.account.id}}'].parent.name"
```

The answer must be `{{resources.account.management_group}}`.
{{/resources.account}}

## A deployment fails with `AuthorizationFailed` on the billing scope

The service principal cannot create a subscription.

1. List the billing accounts that it can read.
   ```bash
   az billing account list --query "[].{name:name, type:agreementType}"
   ```
2. When the list is empty, ask the billing owner for the `Owner` role on the
   enrollment account.
3. Deploy again.

## A deployment fails with `SubscriptionAliasAlreadyExists`

An alias with this name exists. Azure keeps an alias after someone cancels the
subscription.

```bash
az account alias list --query "[].name"
```

Rename the instance, then deploy again.

## The class is wrong

{{#resources.account}}
This subscription carries the class `{{resources.account.landing_zone_class}}`,
and that class decides which bundles a project can use. The field is immutable,
so the form blocks the change. Vend a second subscription with the correct class
and move the workloads to it.
{{/resources.account}}

## A cancelled subscription still appears

Azure keeps a cancelled subscription for 90 days, and it keeps the alias. A
decommission of this instance does not delete the resources inside the
subscription. Move or delete those resources first.

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
