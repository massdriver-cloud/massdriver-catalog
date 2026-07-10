# Changelog

All notable changes to the `aws-eks-cluster` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-10

### Added
- Real OpenTofu EKS: cluster + one managed node group on the connected VPC's private subnets (falls back to all subnets if the network has no private tier).
- Region derived from the connected `aws-network` — no region parameter to get wrong.
- `kubernetes_version` dropdown (1.29 / 1.30 / 1.31), upgradeable in place.
- T-shirt `node_instance_size` (Small t3.medium / Medium m6i.large / Large m6i.xlarge) mapped to instance types in a Terraform local.
- `min_nodes` / `max_nodes` steppers; live desired count ignored on deploy so autoscalers keep ownership.
- `public_api_endpoint` toggle — the related Checkov finding is deliberately left unskipped so enabling it warns in dev.
- Control plane logs (`api`, `audit`, `authenticator`) always on.
- `Control Plane Storage Nearly Full` alarm (`AWS/EKS` `apiserver_storage_size_bytes` vs the 8 GiB etcd limit).
- `params.examples`: Development / Production presets.
- Emits a `kubernetes-cluster` resource: ARN, name, version, OIDC issuer URL, and kubeconfig-shaped credentials.
