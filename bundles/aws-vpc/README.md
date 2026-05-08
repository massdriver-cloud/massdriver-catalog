# aws-vpc

Stands up an Amazon VPC with public and private subnets across multiple availability zones, sized and configured for downstream workloads (EKS, RDS, internal services). Built on top of `terraform-aws-modules/vpc/aws`.

## What it provisions

- VPC with the configured IPv4 CIDR
- Public and private subnets across the chosen number of AZs (2 or 3)
- Internet Gateway + public route tables
- NAT Gateway(s): `single`, `per-az`, or `none` for outbound internet from private subnets
- Locked-down default security group and default NACL
- Optional VPC Flow Logs to CloudWatch
- Optional DNS hostnames (required by RDS, ALB, etc.)

## Connections

- `aws_authentication: aws-iam-role` — env-default, supplies the role used to provision

## Outputs

- `vpc: aws-vpc` — VPC ID, CIDR, public + private subnet IDs, AZ list. Downstream bundles (EKS, RDS, etc.) consume this to place themselves inside the network.

## Configuration highlights

- **`region`** — AWS region. Marked immutable: changing it requires a new VPC and migrating workloads.
- **`cidr`** — Primary /16 IPv4 CIDR. Marked immutable; pick something that does not overlap with peered networks.
- **`availability_zone_count`** — 2 or 3 AZs. Immutable. Use 3 for production.
- **`nat_gateway_mode`** — `single` (cheap, one AZ failure domain), `per-az` (HA, ~3x cost), or `none` (no outbound internet from private subnets).
- **`enable_flow_logs`** — Ships VPC Flow Logs to CloudWatch. Default on; useful for security and traffic analysis.

See `massdriver.yaml` for the full param surface.

## Compliance

The bundle ships a `.checkov.yml` skip list containing only false positives plus the project-wide no-CMK policy. Production environments (`md-target` matching `^(prod|prd|production)$`) hard-fail on Checkov findings; lower environments surface findings as warnings.

## Operator runbook

See [`operator.md`](./operator.md) for `aws ec2` operations and troubleshooting.
