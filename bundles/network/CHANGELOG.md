# Changelog

## 0.1.0 — 2026-05-14

### Added
- `params.examples`: Small / Medium / Large presets covering single-AZ dev, multi-subnet staging, and full HA production layouts.
- `enable_flow_logs` parameter with a `flow_log_retention_days` setting (1–365 days).
- `dns_servers` array (max 4, IPv4-validated) for environments forwarding DNS to on-prem.
- `subnets[].type` enum (`public` / `private`) so the producing IaC stops guessing visibility from order.
- `subnets[].name` pattern validation with a custom `message.pattern` error.
- `$md.immutable` on `cidr` — changing it forces a destroy-and-recreate, so the form blocks it after the first deploy.
- UI tweaks: `ui:help` on `cidr` / `flow_log_retention_days` / `dns_servers`; `ui:widget: updown` on retention; orderable / addable / removable subnets.
- 2am runbook filed by symptom: egress anomalies, NAT port exhaustion, dropped connections with no application-side explanation, subnet exhaustion, CIDR overlap before a deploy, and the re-IP playbook.
- Two `massdriver_instance_alarm` stand-ins (`Egress Throughput Anomaly`, `NAT Port Exhaustion`).

### Changed
- Provider constraint `massdriver-cloud/massdriver` bumped to `~> 2.0`.
- `massdriver_artifact` → `massdriver_resource` in `src/resources.tf` (artifact arg → resource arg). `massdriver_artifact` is removed in provider v2.0.
- `subnets[].type` is no longer inferred from index; it's an explicit field on each subnet.

### Removed
- `operator.md` placeholder sections (`Welcome / What to Include / Pro Tips`) — replaced with runbook-grade content.

## 0.0.0 — initial draft
- `cidr` + free-form `subnets` list, single OpenTofu step, `random_pet`-based stub IaC, default-template operator runbook.
