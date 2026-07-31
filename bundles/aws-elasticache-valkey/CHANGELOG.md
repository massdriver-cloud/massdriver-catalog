# Changelog

All notable changes to the `aws-elasticache-valkey` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Real Terraform/OpenTofu: ElastiCache replication group running Valkey, private subnet group, security group scoped to the VPC CIDR only.
- At-rest and in-transit encryption plus a generated auth token, all non-configurable — session/cache data is sensitive by default.
- `high_availability` toggle: 1 node by default, 2 nodes + automatic failover when on.
- Emits `redis-connection`: id, engine (`valkey`), version, tls_enabled, auth (hostname/port/password).

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
