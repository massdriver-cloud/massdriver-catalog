# AWS ECR Repository

A private Amazon ECR repository for container images: vulnerability scanning on push, AES256 encryption at rest, and a lifecycle policy that automatically deletes old images so storage costs stay flat.

## What it shows

- **Self-service experience** — Development / Production presets, an immutable `repository_name` with a friendly validation message, a tag-mutability selector with the tradeoff spelled out in the labels, and an image-retention spinner backed by a real lifecycle policy.
- **Operator guide** (`operator.md`) — a 2am runbook templated with the live repository URL: rejected pushes, critical scan findings, cluster pull failures.
- **Compliance** — tag immutability and scan-on-push default to the safe setting, so the matching Checkov checks pass without being skipped; only the customer-managed-KMS check is skipped, with the reasoning documented in `src/.checkov.yml`.
- **IaC code** (`src/`) — real, minimal OpenTofu: one repository and one lifecycle policy.

No alarms in this bundle — ECR has no always-on CloudWatch metric worth waking anyone up for. Pull failures show up on the workloads that pull, where this catalog's compute bundles alarm.

## What it produces

A `container-registry` resource: repository ARN, registry hostname (for `docker login`), full repository URL (for `docker push` and image references), repository name, and region. Consumed by bundles and CI pipelines that build and deploy container images.

Pushing an image with the artifact fields:

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <registry_url>
docker tag my-app:v1.0.0 <repository_url>:v1.0.0
docker push <repository_url>:v1.0.0
```

## Costs to know about

ECR storage is ~$0.10/GB-month — effectively free at demo scale, and the lifecycle policy keeps it bounded as CI pushes pile up. Data transfer out to the internet is billed, but pulls from AWS in the same region are free.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
