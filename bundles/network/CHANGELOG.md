# Changelog

All notable changes to the `network` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-14

### Added
- `params.examples`: Small / Medium / Large presets covering single-AZ dev, multi-subnet staging, and full HA production layouts.
- `enable_flow_logs` parameter with a `dependencies` block that requires `flow_log_retention_days` only when flow logs are turned on.
- `dns_servers` array (max 4, IPv4-validated) for environments forwarding DNS to on-prem.
- `subnets[].type` enum (`public` / `private`) so the producing IaC stops guessing visibility from order.
- `subnets[].name` pattern validation with a custom `message.pattern` error.
- `$md.immutable` on `cidr` — changing it forces a destroy-and-recreate, so the form blocks it after the first deploy.
- UI tweaks: `ui:help` on `cidr` / `flow_log_retention_days` / `dns_servers`; `ui:widget: updown` on retention; orderable / addable / removable subnets.
- Real 2am runbook content: alarm-response steps, subnet-exhaustion check, flow-log queries, re-IP playbook.
- Two `massdriver_instance_alarm` stand-ins (`Egress Throughput Anomaly`, `NAT Port Exhaustion`) wired through the new `massdriver-cloud/massdriver` `~> 1.4` provider.

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped from `~> 1.3` to `~> 1.4`.
- `massdriver_artifact` → `massdriver_resource` in `src/artifacts.tf` (artifact arg → resource arg). `massdriver_artifact` is removed in provider v2.0.
- `subnets[].type` is no longer inferred from index; it's an explicit field on each subnet.

### Removed
- `operator.md` placeholder sections (`Welcome / What to Include / Pro Tips`) — replaced with runbook-grade content.

## [0.0.0] — initial draft
- `cidr` + free-form `subnets` list, single OpenTofu step, `random_pet`-based stub IaC, default-template operator runbook.
