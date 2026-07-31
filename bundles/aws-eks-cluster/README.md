# AWS Kubernetes Cluster

Provisions an Amazon EKS cluster: a managed control plane, a managed node group in private subnets, an IAM OIDC provider for IRSA, and the AWS Load Balancer Controller. Emits a `kubernetes-cluster` resource that every app bundle connects to.

## What it provisions

- A managed Kubernetes control plane. Worker nodes run in private subnets and are not directly reachable from the internet.
- An IAM OIDC provider so each app's Kubernetes service account can assume a scoped IAM role (IRSA) instead of holding static access keys. The storage and queue bundles' access policies rely on this mechanism.
- The AWS Load Balancer Controller, installed via Helm. When an app declares an Ingress, the controller provisions a load balancer with TLS termination if a certificate is configured.

## Parameters worth knowing

- The API endpoint is IAM-authenticated regardless of the `endpoint_public_access` setting; the toggle only controls network reachability. In production, restrict `public_access_cidrs` to known ranges.
- `acm_certificate_arn` is not created for you. Issuing and DNS-validating an ACM certificate requires access to your domain's DNS zone. Leave it blank to serve ingress over HTTP until a certificate is available.
- The node pool is shared by every app on the cluster, so size it for the busiest app. The control plane carries a fixed hourly charge, which is why apps share one cluster rather than each getting their own.

## Operational notes

- `src/main.tf` provisions the control plane, node group, and OIDC provider. `src/ingress.tf` installs the AWS Load Balancer Controller via Helm.
- Before production, replace `src/aws-load-balancer-controller-iam-policy.json` with the full, current policy from the [aws-load-balancer-controller releases](https://github.com/kubernetes-sigs/aws-load-balancer-controller). The policy shipped here covers common paths only.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
