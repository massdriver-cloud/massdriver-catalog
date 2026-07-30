# AWS Kubernetes Cluster

This bundle creates the shared home your apps run in: an Amazon EKS (Kubernetes) cluster. Every app you deploy on this platform lands here as a container — nothing gets its own cluster, because the control plane has a fixed hourly cost whether one app uses it or ten.

## What you get

- A managed Kubernetes control plane, with worker nodes (the machines your containers actually run on) placed in private subnets — they're not directly reachable from the internet.
- A way for your apps to get their own scoped cloud permissions without ever holding a static access key. Each app's Kubernetes service account can be trusted, through this cluster, to assume just the IAM role it needs — nothing more. This is the mechanism the storage, queue bundles rely on for "scoped IAM access."
- An ingress controller already installed, so when an app declares an Ingress (its "please route traffic to me" object), a load balancer shows up automatically with HTTPS termination — as long as you've given it a certificate.

## Who uses this

Every app bundle connects here to get deployed. The shared node pool means the size you pick has to fit your busiest app, not your average one.

## Things worth knowing before you deploy

- **The API endpoint is IAM-authenticated no matter what.** The public/private endpoint toggle only controls network reachability, not who's allowed in.
- **The HTTPS certificate isn't created for you.** Issuing and DNS-validating an ACM certificate needs your domain's DNS zone, which this bundle doesn't have access to — bring an existing certificate ARN, or leave it blank and run over HTTP until you're ready for a real domain.
- **The node pool is shared.** If one app starts needing 10x the compute, that's a signal to size up the whole cluster, not to spin up a second one — a second cluster means paying for a second control plane.

## Customize it

1. Edit `massdriver.yaml` for different instance sizes, version support, or node count ranges.
2. `src/main.tf` provisions the real control plane, node group, and OIDC provider. `src/ingress.tf` installs the AWS Load Balancer Controller via Helm.
3. **Before production:** replace `src/aws-load-balancer-controller-iam-policy.json` with the full, current policy from the [aws-load-balancer-controller releases](https://github.com/kubernetes-sigs/aws-load-balancer-controller) — what ships here is a trimmed-down version covering the common paths, not the exhaustive official policy.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
