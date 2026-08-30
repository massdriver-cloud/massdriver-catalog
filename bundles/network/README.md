# Network

A virtual network with subnets, optional flow-log retention, and DNS configuration.

> [!NOTE]
> This is a **placeholder bundle**. It ships with a complete schema and a stub `random_pet` IaC so you can poke at the developer experience on the Massdriver canvas before writing any real Terraform/OpenTofu. Once the shape feels right, swap the stub for your real network module.

## What it shows

This bundle is a worked example of the four things every bundle in the catalog brings together:

- **Self-service experience** — the params (CIDR, subnets, flow logs, DNS servers) are what your developers fill out. Small, Medium and Large presets fill the whole form in one click. Subnets are a re-orderable list where each one declares whether it is public or private, rather than the IaC guessing from position. Every CIDR field explains what a valid value looks like when you get it wrong.
- **Operator guide** (`operator.md`) — a 2am runbook, templated so it shows this network's live CIDR, its subnets, and whether flow logs are on.
- **Compliance** — `$md.immutable: true` on `cidr`, because re-IPing a network is a migration and not an edit, and the form should say so before the deploy does. Two `massdriver_instance_alarm` definitions: `Egress Throughput Anomaly` and `NAT Port Exhaustion`.
- **IaC code** (`src/`) — a placeholder module that wires `params` into `massdriver_resource` outputs. Replace it with your real network module.

## Customize it

1. Edit `massdriver.yaml` — match the params to the inputs your network module actually takes (region, peering, transit gateway IDs, and so on). The [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) covers every key.
2. Rewrite `src/` to be your real Terraform/OpenTofu. `_massdriver_variables.tf` regenerates from your params and connections on every `mass bundle build`, so the schema and the variables stay in sync.
3. Update `operator.md` with your team's actual runbook — re-IP playbook, NAT exhaustion fix, on-call escalation.
4. Tune the alarm definitions in `src/alarms.tf` to thresholds your team will actually wake up for.
