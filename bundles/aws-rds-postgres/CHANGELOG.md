# Changelog

All notable changes to the `aws-rds-postgres` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Real Terraform/OpenTofu: RDS for PostgreSQL, private DB subnet group, security group scoped to the VPC CIDR only, encrypted storage, optional Multi-AZ standby.
- Chose provisioned RDS over Aurora Serverless v2 for this catalog's workloads — the ACU floor (0.5 ACU, ~$44/mo before storage/IO) costs more than a small provisioned instance for genuinely small apps. See README for the math.
- `deletion_protection` (default **true**) and `skip_final_snapshot` (default **false**) — both param-driven and left visible rather than hardcoded, so dev throwaway instances can opt out deliberately.
- Emits `postgres-server`: id, engine, version, region, high_availability, auth (hostname/port/database/username/password).

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
