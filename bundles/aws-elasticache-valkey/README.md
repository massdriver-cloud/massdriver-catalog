# Cache

A fast, in-memory store for anything your app needs to read quickly and doesn't want to hit a database for every time — session data, rate-limit counters, a cache in front of slower lookups, pub/sub between app instances.

## Why Valkey

This runs Valkey, an open, Redis-compatible engine, instead of anything proprietary to AWS. Your app's code just talks the normal Redis wire protocol — if you move to another cloud later, you point at a different endpoint and nothing else changes.

## What you get

- Encrypted at rest and in transit, with a generated auth token — not configurable off, since session data is sensitive by default.
- An optional second node with automatic failover for when you can't afford to lose the cache mid-request.

## Customize it

1. Edit `massdriver.yaml` for a different node size or engine version.
2. `src/main.tf` provisions a real ElastiCache replication group, not a placeholder.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
