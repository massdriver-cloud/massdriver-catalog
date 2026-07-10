# AWS VPC

An AWS VPC with one public and one private subnet per availability zone, an internet gateway, optional NAT gateways, and optional flow logs. This is the foundational network every other bundle in the catalog attaches to.

## What it shows

- **Self-service experience** — Development / Staging / Production presets, an immutable `cidr` with a friendly validation message, a NAT gateway selector with costs spelled out in the labels, and a conditional `flow_log_retention_days` field that only becomes required when flow logs are on.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live VPC's ID, CIDR, and subnet table.
- **Compliance** — the VPC's default security group is locked to deny-all, flow-log findings surface as Checkov warnings in dev when disabled, and a per-NAT `ErrorPortAllocation` alarm registers with the instance health panel.
- **IaC code** (`src/`) — real, minimal OpenTofu: VPC, subnets carved with `cidrsubnet`, route tables, NAT, and conditional flow-log wiring.

## What it produces

An `aws-network` resource: VPC ID, CIDR, region, locked default security group, and the full subnet list (ID, name, CIDR, tier, AZ). Downstream bundles use the subnet list to drive `$md.enum` placement dropdowns.

## Costs to know about

NAT gateways are the only meaningfully billable resource here (~$32/mo each plus data processing). `none` is free; `per_az` in 3 AZs is ~$96/mo before traffic.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
