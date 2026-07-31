# Changelog

All notable changes to the `aws-eks-cluster` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Real Terraform/OpenTofu: EKS control plane in private subnets, managed node group (t-shirt sized instance types), IAM OIDC provider for IRSA.
- AWS Load Balancer Controller installed via the `helm` provider, with its own IRSA role — app Ingress resources get ACM-backed TLS at the ALB they provision.
- `acm_certificate_arn` accepts an existing certificate rather than provisioning one — DNS validation needs a domain this bundle doesn't own.
- `endpoint_public_access` / `public_access_cidrs` toggle, both left as visible (unskipped) compliance considerations since they're param-driven.
- Emits `kubernetes-cluster`: API endpoint, CA cert, OIDC provider arn/url, ingress class + cert arn.

### Known trade-offs (flagged, not hidden)
- `src/aws-load-balancer-controller-iam-policy.json` is a reduced version of AWS's published policy — swap in the full one before production.

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
