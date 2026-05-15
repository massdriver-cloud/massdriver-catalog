# Network

A virtual network with subnets, optional flow-log retention, and DNS configuration.

> [!NOTE]
> This is a **placeholder bundle**. It ships with a complete schema and a stub `random_pet` IaC so you can poke at the developer experience on the Massdriver canvas before writing any real Terraform/OpenTofu. Once the shape feels right, swap the stub for your real network module.

## What it shows

This bundle is a worked example of the four things every bundle in the catalog brings together:

- **Self-service experience** — the params schema (CIDR, subnets, flow logs, DNS servers) is what your developers will fill out. Try the Small / Medium / Large presets, the conditional `flow_log_retention_days` field, and the immutable `cidr`.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live network's CIDR, subnet table, and flow-log settings. Open it from the instance's runbook tab in the UI.
- **Compliance** — two `massdriver_instance_alarm` definitions (`Egress Throughput Anomaly`, `NAT Port Exhaustion`) and immutability markers on fields that should never change post-deploy.
- **IaC code** (`src/`) — a placeholder Terraform/OpenTofu module that wires `params` and `connections` into `massdriver_resource` outputs. Replace it with your real network module.

## Customize it

1. Edit `massdriver.yaml` — adjust the params schema to match the inputs your network module actually takes (region, peering, transit gateway IDs, etc.).
2. Rewrite `src/` to be your real Terraform/OpenTofu. `_massdriver_variables.tf` regenerates from your params + connections on every `mass bundle build`, so the schema and the variables stay in sync.
3. Update `operator.md` with your team's actual runbook steps — re-IP playbook, NAT exhaustion fix, on-call escalation.
4. Tune the alarm definitions in `src/alarms.tf` to thresholds your team will actually wake up for.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
