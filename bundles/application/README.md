# Application

A containerized application — image, replica count, domain, CPU/memory limits, log level — wired to a network, a Postgres database, and (optionally) a bucket.

> [!NOTE]
> This is a **placeholder bundle**. It ships with a complete schema and a stub `random_pet` IaC so you can poke at the developer experience on the Massdriver canvas before writing any real Terraform/OpenTofu. Once the shape feels right, swap the stub for your real deployment module (Helm chart, Kubernetes manifests, ECS task, Cloud Run service — whatever you run).

## What it shows

This bundle is a worked example of the four things every bundle in the catalog brings together:

- **Self-service experience** — labelled `oneOf` dropdowns for `environment` and `log_level`. Kubernetes-style `cpu_limit` / `memory_limit` enums. An `image` pattern that requires `image:tag` or `image@digest`, with `ui:help` explaining why pinning to a real tag makes rollbacks unambiguous. And `$md.enum` pickers for `database_policy` / `bucket_policy` that fill themselves in from the linked resources' `.policies` arrays.
- **Operator guide** (`operator.md`) — a 2am runbook, templated so it shows this instance's live image tag, replica count, domain, and database connection details.
- **Compliance** — a full `app:` block. `app.envs` lifts connection values into env vars with JQ (`DATABASE_HOST`, `DATABASE_URL`, and `BUCKET_NAME` with a `// ""` fallback for when no bucket is linked). `app.secrets` declares `JWT_SECRET` as required, so the UI blocks the deploy until someone sets it, plus optional `SENTRY_DSN` and `GOOGLE_OAUTH_CLIENT_SECRET`. Three `massdriver_instance_alarm` definitions: `Pod Restart Rate`, `5xx Error Rate`, `p95 Latency`.
- **IaC code** (`src/`) — a placeholder module that wires `params` and all three `connections` (network, postgres, optional bucket) into `massdriver_resource` outputs. Replace it with your real deployment module.

## Customize it

1. Edit `massdriver.yaml` — match the params to your real deployment module's inputs (image pull secrets, sidecar containers, autoscaling, and so on), and change the `connections` block to whatever your app actually depends on. The [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) covers every key.
2. Rewrite `src/` to be your real Terraform/OpenTofu or Helm chart. `_massdriver_variables.tf` regenerates from your params and connections on every `mass bundle build`, so the schema and the variables stay in sync.
3. Update `operator.md` with your team's actual runbook — restart loops, rollback procedure, traffic shifting, on-call escalation.
4. Tune the alarm definitions in `src/alarms.tf` to thresholds your team will actually wake up for.
