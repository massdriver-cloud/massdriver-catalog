# Azure SQL Runbook

{{#resources.database}}
| Field | Value |
|---|---|
| Host | `{{resources.database.data.auth.hostname}}` |
| Database | `{{resources.database.data.auth.database}}` |
| Level | `{{resources.database.data.tier}}` |
{{/resources.database}}

## An application cannot connect

**Diagnosis.** The client sits outside the connected network. The server has no
firewall rule for the internet.

**Fix.** Check the network rules.

```bash
az sql server vnet-rule list \
  --server <SERVER> \
  --resource-group <GROUP> \
  --output table
```

## A deployment fails on the size

**Diagnosis.** The Basic level holds 2 GiB at most.

**Fix.** Lower the size, or pick a larger level. The bundle stops this case with
a precondition and a clear message.

## The database is full

**Symptom.** A write fails with error 40544.

**Fix.** Raise the maximum size, or move to a larger level.

## Rotate the administrator password

The bundle creates the password. Deploy the instance again to create a new one.

## Warning: a level change can interrupt a connection

Azure moves the database to new hardware. Open connections drop. Deploy the
change in a maintenance window.
