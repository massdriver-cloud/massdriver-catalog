---
templating: mustache
---

# Cosmos DB Runbook

## Health check

{{#resources.database}}
```bash
az cosmosdb show --ids {{resources.database.id}} \
  --query "{state:provisioningState, consistency:consistencyPolicy.defaultConsistencyLevel}"
```
{{/resources.database}}

## An application gets a timeout

The traffic comes from outside the connected network, and the account refuses
it.

{{#resources.database}}
1. Read the network rules.
   ```bash
   az cosmosdb show --ids {{resources.database.id}} \
     --query "{filter:isVirtualNetworkFilterEnabled, subnets:virtualNetworkRules[].id}"
   ```
2. Confirm that the workload runs in one of those subnets.
3. Confirm that the subnet carries the `Microsoft.AzureCosmosDB` service
   endpoint.
{{/resources.database}}

## An application gets `429 Too Many Requests`

The load passed the reserved rate.

{{#resources.database}}
1. Read the consumption of the last hour.
   ```bash
   az monitor metrics list --resource {{resources.database.id}} \
     --metric NormalizedRUConsumption --interval PT5M --output table
   ```
2. Raise the throughput in the form, or move the account to the serverless mode.
3. A client must also retry after the delay that the answer carries.
{{/resources.database}}

## The cost is higher than you expect

Strong consistency doubles the request cost of a read, and a provisioned account
charges the reserved rate while it is idle. Session consistency covers most
applications, and the serverless mode suits a small load.

## Restore a document

Azure keeps a periodic backup. A restore creates a new account, and it cannot
write into this one.

```bash
az cosmosdb restore --help
```

Open a support case when the backup window has passed.

## The API must change

{{#resources.database}}
This account speaks `{{resources.database.api}}`, and Azure sets that at
creation. A move needs a second account and a data migration.
{{/resources.database}}

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
