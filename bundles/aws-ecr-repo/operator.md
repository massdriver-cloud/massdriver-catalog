---
templating: mustache
---

# ECR Repository Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Repository | `{{artifacts.registry.repository_name}}` |
| Repository URL | `{{artifacts.registry.repository_url}}` |
| Registry host | `{{artifacts.registry.registry_url}}` |
| Region | `{{artifacts.registry.region}}` |
| Tag mutability | `{{params.image_tag_mutability}}` |
| Images kept | `{{params.keep_last_images}}` |

---

## "Push rejected — tag already exists"

Tag mutability is `{{params.image_tag_mutability}}`. If it's `IMMUTABLE`, a tag can never be re-pushed — CI most likely rebuilt an image and tried to reuse the tag.

**Fix now:** push under a new tag (append the git SHA or a build number):

```bash
docker tag my-app:latest {{artifacts.registry.repository_url}}:v1.0.1
docker push {{artifacts.registry.repository_url}}:v1.0.1
```

**Fix later:** make CI derive tags from the commit SHA so no two builds ever share one. Do **not** flip the repository to `MUTABLE` to unblock a pipeline — that trades a build failure for silent image drift in production.

## "Image scan found critical vulnerabilities"

See exactly what was found in the newest image:

```bash
aws ecr describe-image-scan-findings \
  --repository-name {{artifacts.registry.repository_name}} \
  --region {{artifacts.registry.region}} \
  --image-id imageTag=<tag> \
  --query 'imageScanFindings.findings[?severity==`CRITICAL`].[name,uri]' --output table
```

1. Most criticals live in the base image. Bump to the base image's latest patch release, rebuild, push a new tag.
2. If a finding is in your own dependencies, upgrade the package the finding names.
3. Already-deployed images keep running — scanning reports, it doesn't block. Decide with the service owner whether to hotfix or ride until the next release.

## "The cluster can't pull — auth or rate errors"

**`no basic auth credentials` / `authorization token has expired`:** ECR tokens live 12 hours. Clusters using an IAM role (EKS node role, IRSA) refresh automatically — if one is failing, the role is missing `ecr:GetAuthorizationToken` + `ecr:BatchGetImage` + `ecr:GetDownloadUrlForLayer`. A human with a stale local login just needs:

```bash
aws ecr get-login-password --region {{artifacts.registry.region}} | \
  docker login --username AWS --password-stdin {{artifacts.registry.registry_url}}
```

**`pull rate limit` / throttling:** ECR throttles per-account API rates. A node group scaling up all at once is the usual cause; the pulls retry and succeed. If it's chronic, check for pods with `imagePullPolicy: Always` on a hot loop.

**`manifest not found`:** the tag was expired by the lifecycle policy (only the last `{{params.keep_last_images}}` images are kept). Confirm, then re-push or roll forward:

```bash
aws ecr describe-images --repository-name {{artifacts.registry.repository_name}} \
  --region {{artifacts.registry.region}} \
  --query 'sort_by(imageDetails,&imagePushedAt)[].imageTags' --output table
```

If rollback targets keep getting expired, raise `keep_last_images` and redeploy this instance.
