# aws-app

Helm-deployed demo application for AWS. Ships an in-bundle Helm chart that runs nginx (`public.ecr.aws/nginx/nginx:1.27`) on the connected EKS Fargate cluster, with connection metadata from the connected RDS Postgres and S3 bucket wired into the pod as environment variables. Use it as a reference for the wiring pattern; fork the chart or scaffold a new one from `templates/aws-helm-chart/` for real workloads.

## What it provisions

- Helm release into the configured namespace on the connected EKS cluster
- Deployment + Service for `public.ecr.aws/nginx/nginx:1.27` with the configured replica count
- Pod env vars carrying connection metadata: `DB_HOST`, `DB_READER_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_SECRET_ARN`, `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`, `EKS_CLUSTER_NAME`, `EKS_CLUSTER_REGION`

## Connections

- `eks: aws-eks-cluster` — canvas-linked from the `aws-eks-fargate` bundle. Carries the cluster endpoint, CA, and bearer token used by the Helm provisioner.
- `database: aws-rds-postgres` — canvas-linked from the `aws-rds-postgres` bundle. The bundle reads `auth.hostname`, `auth.reader_endpoint`, `auth.port`, `auth.database`, `auth.username`, and `secret_arn`.
- `bucket: aws-s3-bucket` — canvas-linked from the `aws-s3-bucket` bundle. The bundle reads `name`, `region`, and `endpoint`.

## Outputs

- `application: aws-application` — release identity for downstream wiring.

## Configuration highlights

- **`namespace`** — Kubernetes namespace for the release. Marked immutable. Must be covered by a Fargate profile on the connected cluster.
- **`replicas`** — Number of pod replicas (1–50).

See `massdriver.yaml` for the full param surface.

## Helm provisioner contract

The Massdriver helm provisioner reads `kubernetes_cluster.data.authentication.cluster.server`, `…cluster.certificate-authority-data`, and `…user.token`. The `aws-eks-cluster` artifact in this catalog is flat (no `data` wrapper); the bundle's step `config.kubernetes_cluster` jq expression reshapes the flat fields into the v1 contract inline. That keeps the rest of the catalog's resource types free of vestigial `data`/`specs` wrappers.

## Compliance

Production environments (`md-target` matching `^(prod|prd|production)$`) hard-fail on Checkov findings; lower environments surface findings as warnings.

Database credentials are **not** injected as env vars. `DB_SECRET_ARN` points at AWS Secrets Manager. A real workload would pull credentials from there at runtime via an IRSA-bound IAM role (note: this catalog's `aws-eks-fargate` bundle does not provision the OIDC provider; if you fork this bundle for a real workload, set IRSA up out-of-band first). This demo pod does not bind any IAM policies — it's a wiring reference.

## Operator runbook

See [`operator.md`](./operator.md) for `kubectl` and `helm` operations and troubleshooting.
