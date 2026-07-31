# Importing an existing ElastiCache cluster

Use this when you already have an ElastiCache (Valkey or Redis OSS) cluster and want Massdriver to know about it, instead of provisioning a new one with the `aws-elasticache-valkey` bundle.

## Where to find each field

1. Open the **ElastiCache console** → your cluster/replication group.
   - `id`: the cluster or replication group ID.
   - `engine`: `valkey` or `redis`, matching the "Engine" field.
   - `version`: the "Engine version" field.
   - `region`: shown in the top-right of the console.
2. Under **Cluster endpoint**:
   - `auth.hostname`: the primary/configuration endpoint hostname.
   - `auth.port`: the port (default `6379`).
3. Under **Encryption**:
   - `tls_enabled`: true if "Encryption in transit" is enabled.
   - `auth.password`: the AUTH token, if "Encryption in transit" (and AUTH) is enabled. Leave blank for an unauthenticated dev cluster.

## Notes

- This resource type is engine-agnostic (Valkey or Redis OSS). A consuming app can move to another provider's Redis-compatible cache without changing its connection code.
