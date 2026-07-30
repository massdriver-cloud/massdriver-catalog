# Cache

Provisions an ElastiCache replication group running Valkey, an in-memory store for session data, rate-limit counters, caching, and pub/sub between app instances. Emits a `redis-connection` resource with the endpoint and auth token.

## Why Valkey

Valkey is an open, Redis-compatible engine. Apps talk the standard Redis wire protocol, so moving to another provider's Redis-compatible cache later means changing an endpoint, not application code.

## What it provisions

- A replication group encrypted at rest and in transit, with a generated auth token. Encryption is not parameter-configurable.
- An optional replica node with automatic failover (`high_availability`). A replica roughly doubles node cost.

## Operational notes

- Without a replica, losing the node loses every session and cached value it held. Apps should handle a cold cache (re-authenticate, re-fetch) rather than assume the cache survives.
- `src/main.tf` provisions the ElastiCache replication group, subnet group, and security group.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
