# Azure Cosmos DB

This bundle creates a Cosmos DB account and one database.

## Network

The account accepts traffic from the subnets of the connected network only. The
subnets need the `Microsoft.AzureCosmosDB` service endpoint, and the
`azure-virtual-network` bundle sets it.

## Capacity

| Mode | When to use it |
|---|---|
| Serverless | A small load, or an uneven load. Azure charges per request. |
| Provisioned | A steady load above about 1000 RU/s. Azure charges a reserved rate. |

## Fields that you cannot change

The database name, the API, and the capacity mode. Azure sets all three at
creation. A change needs a new account and a data migration.

## Keys

The resource carries a primary key and a read only key. Give an application the
read only key when it does not write.
