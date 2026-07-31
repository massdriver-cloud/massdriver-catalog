# AWS Network

Provisions a VPC with public and private subnets across two or three availability zones, a single shared NAT gateway, and VPC endpoints for S3 and ECR. Emits an `aws-network` resource that every other bundle in this catalog connects to.

## What it provisions

- Public subnets for internet-facing resources (load balancers) and private subnets for everything else (cluster nodes, databases, caches).
- One NAT gateway, shared by all private subnets, for outbound internet access from private workloads. A NAT gateway costs about $32/month plus per-GB data processing.
- A gateway endpoint for S3 and interface endpoints for ECR, so object traffic and container image pulls bypass the NAT gateway.
- Optional VPC flow logs delivered to CloudWatch Logs, with configurable retention.

## Parameters worth knowing

- `cidr` and `az_count` are immutable. Changing either requires deploying a new network and migrating every dependent bundle, so size the CIDR generously; a `/16` leaves room to grow.
- `region` is set here once. Downstream bundles inherit it through the network connection rather than asking for it again.
- Flow logs add per-GB CloudWatch Logs charges.

## Operational notes

- Deploy this bundle first. The cluster, database, cache, queue, and bucket bundles all require the `aws-network` resource it emits.
- `src/main.tf` provisions the VPC, subnets, NAT gateway, route tables, and the S3/ECR endpoints.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
