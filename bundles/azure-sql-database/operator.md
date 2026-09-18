---
templating: mustache
---

# Azure SQL Runbook

## Connect

{{#resources.database}}
```bash
sqlcmd -S {{resources.database.auth.hostname}} \
  -d {{resources.database.auth.database}} \
  -U {{resources.database.auth.username}} \
  -P '<PASSWORD>' -Q "SELECT @@VERSION"
```

Run this from a workload inside the network. The server holds no firewall rule
for the internet.
{{/resources.database}}

## An application cannot connect

{{#resources.database}}
1. Read the network rules of the server.
   ```bash
   az sql server vnet-rule list \
     --server <SERVER> --resource-group <GROUP> --output table
   ```
2. Confirm that the workload runs in one of those subnets.
3. Confirm that the subnet carries the `Microsoft.Sql` service endpoint.
{{/resources.database}}

## A deployment fails on the size

The Basic level holds 2 GiB at most. Lower the size, or pick a larger level. The
bundle stops this case before Azure does, with a clear message.

## The database is full

A write fails with error 40544.

{{#resources.database}}
1. Read the space that the database uses now.
   ```bash
   az monitor metrics list --resource {{resources.database.id}} \
     --metric storage_percent --interval PT15M --output table
   ```
2. Raise the maximum size in the form, or pick a larger level, then deploy.
{{/resources.database}}

## The database is slow

{{#resources.database}}
```bash
az monitor metrics list --resource {{resources.database.id}} \
  --metric dtu_consumption_percent --interval PT5M --output table
```

A reading near 100 percent means that the level is too small for the load.
{{/resources.database}}

## Rotate the administrator password

The bundle creates the password. Deploy this instance again to create a new one,
then restart each application that caches a connection string.

## A level change can drop a connection

Azure moves the database to new hardware, and open connections drop. Make the
change in a maintenance window.

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
