# GCP Cloud Run Service — Application Template

Scaffold a new application bundle for a Cloud Run service with a per-service runtime identity and pick any upstream data artifacts you want this service to consume.

## Use with `mass bundle new`

```
mass bundle new --template gcp-cloud-run-service
```

The CLI will prompt for:
- The bundle's `name` and `description`
- Any connections to add (you'll see a list of artifact definitions published in your Massdriver org — pick the upstream resources this service needs, e.g. a `gcp-pubsub-topic`, `gcp-bigquery-dataset`, or `gcp-storage-bucket`)

## What you get

- Cloud Run v2 service running as its own per-service service account
- Sensible defaults baked in: 1 vCPU, 512Mi memory, internal ingress, port 8080
- Artifact output so downstream bundles can discover the service URL and runtime SA
- Example IAM bindings in `src/iam.tf` for common upstream data resources (Pub/Sub publisher, BigQuery writer, GCS object user) — commented out, ready to uncomment based on which connections you picked
- Example push subscription in `src/push_subscription.tf` — uncomment if you want this service to receive messages from a Pub/Sub topic. Uses a dedicated push-invoker SA and OIDC for authenticated delivery.
- Example VPC connector wiring in `src/main.tf` — uncomment if you want egress to flow through a Serverless VPC Access connector (required for reaching private endpoints like on-prem Kafka via peered networks).

## What to customize

The template is intentionally lean. Only `image` is exposed as a param. Add more params to `massdriver.yaml` as your application needs them (port, memory, environment variables, min/max instances, ingress, etc.). Everything in `src/main.tf` is hardcoded defaults — move anything you want operators to tune into `var.*` and add it to the params block.
