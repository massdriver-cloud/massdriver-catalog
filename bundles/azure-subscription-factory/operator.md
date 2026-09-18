# Subscription Factory Runbook

{{#resources.account}}
| Field | Value |
|---|---|
| Subscription | `{{resources.account.data.id}}` |
| Class | `{{resources.account.data.landing_zone_class}}` |
| Management group | `{{resources.account.data.management_group}}` |
{{/resources.account}}

## A deployment fails with `AuthorizationFailed` on the billing scope

**Diagnosis.** The service principal cannot create a subscription.

**Fix.** Give it the `Owner` role on the enrollment account.

```bash
az billing account list --query "[].{name:name, type:agreementType}"
```

## A deployment fails with `SubscriptionAliasAlreadyExists`

**Diagnosis.** An alias with this name exists. Azure keeps an alias after
someone cancels the subscription.

**Fix.** List the aliases, then pick another instance name.

```bash
az account alias list --query "[].name"
```

## Warning: a cancelled subscription does not disappear

Azure keeps a cancelled subscription for 90 days, and it keeps the alias. A
decommission of this instance does not delete the data inside the subscription.
Move or delete the resources first.

## The class is wrong

The class decides which bundles a project can use. Azure cannot change it here,
because the field is immutable.

**Fix.** Vend a new subscription with the correct class, then move the
workloads.
