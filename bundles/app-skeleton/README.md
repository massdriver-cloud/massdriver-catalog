# App Skeleton

A placeholder application bundle that wires up every data-service connection this catalog offers. It exists to validate the full path (cluster, database, storage, queue, cache, email) on the canvas before migration work on the real apps begins.

## What it deploys

A plain container (`nginx` by default) on the shared Kubernetes cluster, with a Service, an Ingress, and one example scheduled job. It connects to a Postgres database, an object storage bucket, a queue, a Redis-compatible cache, and email sending credentials, but contains no application logic; it validates the wiring only.

## Where the real app bundles come from

Each of the three apps being migrated gets its own bundle generated from `templates/aws-eks-app` (the same template this skeleton came from), trimmed to only the connections that app uses:

- **App 1** (largest): object storage, queues, cache. Database is a phase-one decision; see the project summary.
- **App 2** (smallest): object storage, queues (with a dedicated DLQ), cache, email.
- **App 3**: database (required, no in-place migration path), object storage, queues.

## Customization

Changes to shared behavior belong in `templates/aws-eks-app/` so every future app bundle inherits them. Edit this bundle directly only when testing connection wiring changes.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
