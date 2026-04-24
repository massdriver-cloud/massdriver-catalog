# gcp-cloud-run-service

Google Cloud Run v2 service. Each bundle instance creates its own runtime service account and automatically grants it the minimum-privilege role on any connected upstream artifact (Pub/Sub topic, BigQuery dataset, GCS bucket) — no manual IAM wiring required.

## Use Cases

- Internal APIs and microservices consuming Pub/Sub and BigQuery without internet exposure
- Event-driven workers triggered by Pub/Sub push subscriptions or Cloud Scheduler
- Public HTTPS APIs with anonymous or token-authenticated access
- Data pipeline workers reading from GCS and writing to BigQuery or Pub/Sub

## Use as a Runtime Template

This bundle is an example runtime template — an opinionated standard for how Cloud Run services are provisioned. It encodes a security baseline (per-service workload identity, ingress controls, compliance skips with documented rationale) and auto-wires IAM for common data dependencies.

Typical workflow:
1. Platform team publishes this template bundle (or a fork) to Massdriver.
2. Application developer runs `mass bundle new` pointing at the template to generate a bundle for their specific service.
3. The developer customizes image, connections, environment variables, and app-specific dependencies. The platform baseline is inherited.

<!-- TODO: add link to mass bundle new template workflow docs -->

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_service_account.runtime` | Per-service runtime SA | This service's workload identity — one per bundle instance |
| `google_cloud_run_v2_service.main` | Cloud Run v2 service | Runs containers as the runtime SA |
| `google_cloud_run_v2_service_iam_member` (allUsers) | Public invoker IAM | Created only when `allow_unauthenticated = true` |
| `google_pubsub_topic_iam_member` | Pub/Sub publisher IAM | Created only when Pub/Sub topic is connected |
| `google_bigquery_dataset_iam_member` | BigQuery data editor IAM | Created only when BigQuery dataset is connected |
| `google_storage_bucket_iam_member` | GCS object user IAM | Created only when Storage bucket is connected |

## Connections

### Required

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | GCP credentials used by Terraform to provision resources |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id` and `network.region` |

### Optional

When connected on the canvas, the bundle automatically grants this service's runtime SA the listed IAM role. When absent, no binding is created.

| Connection | Artifact Type | IAM Role Granted |
|---|---|---|
| `pubsub_topic` | `catalog-demo/gcp-pubsub-topic` | `roles/pubsub.publisher` on the topic |
| `bigquery_dataset` | `catalog-demo/gcp-bigquery-dataset` | `roles/bigquery.dataEditor` on the dataset |
| `storage_bucket` | `catalog-demo/gcp-storage-bucket` | `roles/storage.objectUser` on the bucket |

Connecting or disconnecting a canvas wire does not take effect until a Terraform apply runs.

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-cloud-run-service`

| Field | Type | Description |
|---|---|---|
| `project_id` | string | GCP project that owns the service |
| `service_name` | string | Short service name (used in gcloud commands) |
| `service_url` | string | HTTPS URL of the service (`.run.app` domain) |
| `location` | string | GCP region where the service is deployed |
| `latest_ready_revision` | string | Name of the currently-serving revision |
| `runtime_service_account_email` | string | Email of this service's own runtime SA |
| `runtime_service_account_member` | string | IAM principal string (`serviceAccount:<email>`) for downstream bindings |

`runtime_service_account_member` is designed for downstream bundles (Scheduler, Pub/Sub push) that need to grant `roles/run.invoker` to this service's identity.

## Compliance

### Hardcoded controls

| Control | Value | Reason |
|---|---|---|
| Per-service runtime identity | `google_service_account.runtime` (one per bundle instance) | Each service gets its own SA with bindings only to resources it connects to — no shared SA that grants access across all workloads |
| Resource labels | Massdriver default tags | Enforces cost attribution and environment tagging on all revisions |

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_102` | Ingress is intentionally configurable. The check fires on any non-internal service without distinguishing IAM controls. Internal-preset services pass this check without the skip; only public-ingress services need it bypassed. |
| `CKV_GCP_103` | Binary Authorization requires a pre-configured attestor policy at the project level. Enabling it per-service without an attestor causes all deployments to fail. Teams requiring binary authorization should enforce it via `google_binary_authorization_policy`. |

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- The landing zone provides `project_id` and `network.region`. It does NOT provide a workload SA — this bundle creates its own.
- The runtime SA does not automatically have `roles/artifactregistry.reader`. If your image is in Artifact Registry, grant that role manually or add it to the bundle source.
- VPC connector or direct VPC egress is not provisioned by this bundle. If you need to reach VPC-private resources (e.g., Cloud SQL without public IP), add a `google_vpc_access_connector` resource to the bundle source.
- The default image (`gcr.io/cloudrun/hello`) is the Google-managed hello-world container. Replace it with your application image before a real deployment.

## Presets

| Preset | Ingress | Min Instances | Max Instances | CPU | Memory | Unauthenticated |
|---|---|---|---|---|---|---|
| Internal | `internal` | 0 | 10 | 1 | 512Mi | false |
| Public API | `all` | 1 | 100 | 2 | 1Gi | true |
| Worker | `internal` | 1 | 50 | 2 | 2Gi | false |
