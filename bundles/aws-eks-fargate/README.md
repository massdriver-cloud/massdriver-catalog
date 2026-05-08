# aws-eks-fargate

Stands up an Amazon EKS cluster running entirely on Fargate — no node groups, no Karpenter, no host-level patching. Wires in OIDC for IRSA, a Massdriver service account for downstream Helm releases, and a CoreDNS patch so DNS works on a Fargate-only cluster.

## What it provisions

- EKS control plane at the configured Kubernetes version
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- Fargate profile(s) covering the configured namespaces
- CoreDNS annotation patch so it schedules onto Fargate (without this, DNS will not start)
- In-cluster `massdriver` ServiceAccount + ClusterRoleBinding + long-lived bearer-token Secret
- Cluster security group, encrypted control plane logs (configurable types) to CloudWatch
- Optional KMS envelope encryption for Kubernetes Secrets in etcd

## Connections

- `aws_authentication: aws-iam-role` — env-default, supplies the provisioning role
- `vpc: aws-vpc` — canvas-linked, places the cluster into existing public/private subnets

## Outputs

- `kubernetes_cluster: aws-eks-cluster` — cluster name, ARN, OIDC issuer, and a `data` block with v1-shaped helm-provisioner auth (API server URL, cluster CA, bearer token). Downstream Helm bundles read this to deploy without separate kubeconfig handling.

## Configuration highlights

- **`cluster_name`** — Name used in IAM trust policies and the kubeconfig context. Marked immutable; pick something stable.
- **`kubernetes_version`** — EKS minor version. In-place minor upgrades supported; downgrades are not.
- **`fargate_namespaces`** — Namespaces whose pods schedule onto Fargate. Must include `kube-system` so CoreDNS has somewhere to run.
- **`endpoint_access`** — `public-and-private` or `private-only`. Production should be `private-only`; combine with `public_access_cidrs` if public access is required.
- **`secrets_encryption_enabled`** — KMS envelope encryption for etcd-stored Secrets. Marked immutable; cannot be turned off after cluster creation.

See `massdriver.yaml` for the full param surface.

## Compliance

The bundle ships a `.checkov.yml` skip list containing only false positives plus the project-wide no-CMK policy. Production environments (`md-target` matching `^(prod|prd|production)$`) hard-fail on Checkov findings; lower environments surface findings as warnings.

## Operator runbook

See [`operator.md`](./operator.md) for `aws eks` and `kubectl` operations and troubleshooting.
