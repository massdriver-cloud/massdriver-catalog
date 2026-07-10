# Changelog

All notable changes to the `aws-vpc` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Real OpenTofu VPC: public/private subnet pair per AZ (2–3 AZs), internet gateway, route tables.
- `nat_gateway` selector (`none` / `single` / `per_az`) with monthly costs in the option labels.
- `params.examples`: Development / Staging / Production presets.
- `$md.immutable` on `region` and `cidr`; `message.pattern` override on `cidr`.
- Conditional `dependencies` block: `flow_log_retention_days` required only when `enable_flow_logs` is on.
- Optional CloudWatch flow logs (log group + IAM role + `aws_flow_log`).
- Default security group locked to deny-all.
- `NAT Port Exhaustion` alarm per NAT gateway (`AWS/NATGateway` `ErrorPortAllocation`).
- Emits an `aws-network` resource with the full subnet list for downstream `$md.enum` dropdowns.
