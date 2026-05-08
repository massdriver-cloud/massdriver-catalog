# aws-eks-fargate

Stands up an Amazon EKS cluster running entirely on Fargate — no node groups, no Karpenter, no host-level patching. Provisions the control plane, Fargate profiles for the namespaces you list, and a long-lived bearer token used by the Massdriver helm provisioner.

## What it provisions

- EKS control plane at the configured Kubernetes version
- Fargate profile(s) covering the configured namespaces
- IAM roles for the cluster and the Fargate pod-execution role
- In-cluster `massdriver` ServiceAccount + ClusterRoleBinding + long-lived bearer-token Secret. The token is exposed on the artifact for the Massdriver helm provisioner; downstream Helm bundles deploy onto the cluster without separate kubeconfig handling.

## Connections

- `aws_authentication: aws-iam-role` — env-default, supplies the provisioning role
- `vpc: aws-vpc` — canvas-linked, places the cluster into existing public/private subnets

## Outputs

- `kubernetes_cluster: aws-eks-cluster` — cluster name, ARN, API endpoint, base64 CA bundle, region, Kubernetes version, VPC ID, Fargate profile inventory, and a long-lived bearer token bound to the in-cluster `massdriver` ServiceAccount.

## Configuration highlights

- **`cluster_name`** — Name used in IAM trust policies and the kubeconfig context. Marked immutable; pick something stable.
- **`kubernetes_version`** — EKS minor version. In-place minor upgrades supported; downgrades are not.
- **`fargate_namespaces`** — Namespaces whose pods schedule onto Fargate. Add any namespace you intend to schedule pods into.

See `massdriver.yaml` for the full param surface.

## Out of scope

- **CoreDNS.** The bundle does not manage CoreDNS. The cluster ships with whatever EKS provisions by default. If your workloads require cluster DNS, configure CoreDNS yourself.
- **IRSA / OIDC provider.** The bundle does not create an `aws_iam_openid_connect_provider`. If a workload needs IRSA, fetch the issuer URL with `aws eks describe-cluster --query 'cluster.identity.oidc.issuer'` and create the provider out-of-band.
- **Control-plane logging.** No CloudWatch log group is provisioned. Enable control-plane log types on the cluster directly if needed.
- **KMS envelope encryption for Secrets.** Not configured.
- **API endpoint access controls.** The cluster API endpoint is configured for both public and private access; `public_access_cidrs` is not exposed.

## Compliance

The bundle ships a `.checkov.yml` skip list containing only false positives plus the project-wide no-CMK policy. Production environments (`md-target` matching `^(prod|prd|production)$`) hard-fail on Checkov findings; lower environments surface findings as warnings.

## Operator runbook

See [`operator.md`](./operator.md) for `aws eks` and `kubectl` operations and troubleshooting.
