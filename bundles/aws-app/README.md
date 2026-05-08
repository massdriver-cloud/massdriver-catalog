# aws-app

Helm-deployed demo application for AWS. Runs `mendhak/http-https-echo` on the connected EKS cluster with connection metadata wired into pod env vars and IRSA-bound IAM policies for the connected RDS database and S3 bucket. Use it as a reference for the wiring pattern; fork the chart or scaffold a new one from `templates/aws-helm-chart/` for real workloads.

## What it provisions

- Helm release into the configured namespace on the connected EKS cluster
- Deployment of `mendhak/http-https-echo` with the configured replica count
- ServiceAccount + IRSA-bound IAM role
- IAM role bindings to the database policy and bucket policy chosen from the upstream bundles
- Pod env vars carrying connection metadata (DB host/port/name, bucket name, upload prefix, log level)

## Connections

- `kubernetes_cluster: aws-eks-cluster` — canvas-linked from the EKS bundle
- `database: aws-rds-postgres` — canvas-linked from the RDS bundle
- `bucket: aws-s3-bucket` — canvas-linked from the S3 bundle

## Outputs

- `application: aws-application` — release identity for downstream wiring (ingress, observability, etc.).

## Configuration highlights

- **`namespace`** — Kubernetes namespace for the release. Marked immutable. Must be covered by a Fargate profile on the connected cluster.
- **`replicas`** — Number of pod replicas (1–50).
- **`database_policy`** — Which IAM policy from the connected RDS bundle to bind to the workload's IAM role (e.g. `Read`, `Write`).
- **`bucket_policy`** — Which IAM policy from the connected S3 bundle to bind. Use `Presign Upload` for browser-direct uploads.
- **`upload_prefix`** — Object key prefix for user-uploaded content. Per-tenant prefixes simplify bulk delete later.

See `massdriver.yaml` for the full param surface.

## Compliance

The chart ships a `.checkov.yml` at `chart/.checkov.yml` containing only false positives plus the project-wide no-CMK policy. Production environments (`md-target` matching `^(prod|prd|production)$`) hard-fail on Checkov findings; lower environments surface findings as warnings.

Note: database credentials are **not** injected as env vars. The workload's IAM role is bound to the selected database and bucket policies via IRSA, and the application is expected to pull master credentials from AWS Secrets Manager at runtime (or use IAM database authentication).

## Operator runbook

See [`operator.md`](./operator.md) for `kubectl` and `helm` operations and troubleshooting.
