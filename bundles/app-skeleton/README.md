# App Skeleton

This isn't one of the three real apps being migrated — it's a placeholder that wires up every data-service connection this catalog offers, so the whole path from cluster to database to storage to queue to cache to email can be proven out on the canvas before the real migration work starts.

## What it actually does

Deploys a plain container (`nginx` by default) onto the shared Kubernetes cluster, with a Service, an Ingress, and one example scheduled job. It connects to a Postgres database, an object storage bucket, a queue, a Redis-compatible cache, and email sending credentials — but doesn't do anything with any of them. The point is proving the wiring works, not the business logic.

## Where the real apps come from

When migration work starts, each of the three real apps gets its own bundle generated from `templates/aws-eks-app` — the same template this skeleton came from — and then trimmed down to only the connections that app actually needs:

- **App 1** (largest): object storage, queues, cache. Database is a phase-one decision — see the project summary for why it's not wired yet.
- **App 2** (smallest): object storage, queues (with a dedicated DLQ), cache, email.
- **App 3**: database (required, no in-place migration path), object storage, queues.

## Customize it

This bundle itself generally shouldn't need customizing — if you want to change the shared template's behavior, edit `templates/aws-eks-app/` instead, so every future app benefits. Edit this bundle directly only if you're using it as a genuine sandbox to test connection wiring changes.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
