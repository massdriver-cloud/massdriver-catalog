# Cosmos DB Runbook

{{#resources.database}}
| Field | Value |
|---|---|
| Account | `{{resources.database.data.name}}` |
| Database | `{{resources.database.data.database}}` |
| API | `{{resources.database.data.api}}` |
| Consistency | `{{resources.database.data.consistency}}` |
{{/resources.database}}

## An application gets a timeout

**Diagnosis.** The traffic comes from outside the connected network. The account
refuses it.

**Fix.** Check the network rules.

```bash
az cosmosdb show --name <ACCOUNT> --resource-group <GROUP> \
  --query "virtualNetworkRules"
```

## An application gets `429 Too Many Requests`

**Diagnosis.** The load passed the reserved rate.

**Fix.** Raise the throughput, or move to the serverless mode. A client should
also retry after the delay that the response carries.

## The cost is higher than you expect

**Diagnosis.** Strong consistency doubles the request cost of a read. A
provisioned account charges the reserved rate even while it is idle.

**Fix.** Use session consistency, or move a small workload to the serverless
mode.

## Warning: the API cannot change

A move from the NoSQL API to the MongoDB API needs a new account and a data
migration. Massdriver locks the field after the first deployment.
