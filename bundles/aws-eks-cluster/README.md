# AWS EKS Cluster

An Amazon EKS cluster with one managed node group, placed on the private subnets of a connected VPC. It emits a `kubernetes-cluster` resource — endpoint, CA, and token — that any workload bundle can consume.

## What it shows

- **Self-service experience** — Development / Production presets, a t-shirt node size picker (real instance types and specs in the labels), version pinned to a dropdown of supported releases, and up/down steppers for node counts.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live cluster's name and ARN: getting kubectl access, nodes NotReady, image pull failures.
- **Compliance** — control plane audit logs (`api`, `audit`, `authenticator`) are always on, and the public API endpoint deliberately surfaces a Checkov warning when enabled so dev teams see the tradeoff. A `Control Plane Storage Nearly Full` alarm watches etcd against its hard 8 GiB limit.
- **IaC code** (`src/`) — real, minimal OpenTofu: two IAM roles, the cluster, one node group. The region comes from the connected network — no way to deploy a cluster into the wrong VPC's region.

## What it produces

A `kubernetes-cluster` resource: cluster ARN, name, version, OIDC issuer URL (for granting pods IAM permissions), and kubeconfig-shaped credentials (API server URL, CA data, bearer token). The resource type includes a downloadable kubeconfig export.

## Costs to know about

The EKS control plane is ~$73/mo (about $0.10/hr) the moment it exists — there is no free tier. Nodes are on top of that, per node: Small (t3.medium) ~$30/mo, Medium (m6i.large) ~$70/mo, Large (m6i.xlarge) ~$140/mo. A dev cluster at the defaults (one Small node) runs ~$103/mo.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
