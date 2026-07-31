# Changelog

All notable changes to the `aws-vpc` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Real Terraform/OpenTofu: VPC, public/private subnets across 2 or 3 AZs, single shared NAT gateway, S3 gateway endpoint, and ECR (api + dkr) interface endpoints with a dedicated security group.
- Optional VPC flow logs to CloudWatch Logs (`enable_flow_logs` / `flow_log_retention_days`), on by default.
- `region` and `cidr` params marked `$md.immutable: true` — this is the one bundle in the catalog that defines region; everything downstream derives it from the connected network.
- Emits `aws-network`: VPC id, CIDR, subnets (with AZ + type), NAT gateway id, S3 endpoint id, ECR endpoint ids.
- 2am runbook covering NAT port exhaustion and ECR endpoint health, plus flow-log starter queries.

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
