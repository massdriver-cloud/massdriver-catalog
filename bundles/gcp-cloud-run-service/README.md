# gcp-cloud-run-service

Google Cloud Run v2 service with automatic IAM binding for upstream data artifacts. The service runs as the landing zone's shared workload service account, and any optional upstream artifact connection (Pub/Sub topic, BigQuery dataset, GCS bucket) automatically grants the workload SA the minimum-privilege role on that resource — no manual IAM wiring required.

## Use Cases

- **Internal APIs and microservices** — low-latency HTTP services behind a load balancer or internal ingress, consuming Pub/Sub and BigQuery without internet exposure.
- **Event-driven workers** — services triggered by Pub/Sub push subscriptions or Cloud Scheduler, reading from GCS and writing to BigQuery.
- **Public APIs** — internet-facing HTTPS services with anonymous or token-authenticated access.
- **Data pipelines** — pull-based workers that read from GCS buckets and publish results to Pub/Sub or BigQuery.

## Use as a Runtime Template

This bundle is an example **runtime template** — an opinionated, org-wide standard for how Cloud Run services are provisioned. It encodes your platform's security baseline (workload identity, ingress controls, compliance skips with documented rationale) and auto-wires IAM for common data dependencies.

The typical workflow for application teams:

1. **Ops/platform team** publishes this template bundle (or a fork of it) to Massdriver.
2. **Application developer** runs `mass bundle new` pointing at the template to generate a new bundle for their specific application. They customize it with their app's image, connections, environment variables, and any app-specific dependencies.
3. The per-app bundle inherits the org's runtime standards from the template; the developer only changes what's specific to their application.

This separation keeps the platform baseline consistent across all services while letting application teams move independently.

For more on the `mass bundle new` workflow and template structure, see the Massdriver documentation. {{TODO: add direct link to the templates repository — check https://github.com/massdriver-cloud/massdriver-catalog or the `mass bundle new --help` output for the template path configuration.}}

## Resources Created

| Resource | Description |
|---|---|
| `google_cloud_run_v2_service` | The Cloud Run v2 service running your container |
| `google_cloud_run_v2_service_iam_member` (allUsers) | Created only when `allow_unauthenticated = true` — grants public invoke access |
| `google_pubsub_topic_iam_member` | Created only when Pub/Sub topic is connected — grants `roles/pubsub.publisher` to workload SA |
| `google_bigquery_dataset_iam_member` | Created only when BigQuery dataset is connected — grants `roles/bigquery.dataEditor` to workload SA |
| `google_storage_bucket_iam_member` | Created only when Storage bucket is connected — grants `roles/storage.objectUser` to workload SA |

## Connections

### Required

| Connection | Artifact Type | Purpose |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | GCP credentials used by Terraform to provision resources |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id`, `network.region`, and `workload_identity.service_account_email` |

### Optional

These connections are not required. When wired on the canvas, the bundle automatically grants the workload service account the appropriate IAM role on the upstream resource. When absent, no IAM binding is created.

| Connection | Artifact Type | IAM Role Granted |
|---|---|---|
| `pubsub_topic` | `catalog-demo/gcp-pubsub-topic` | `roles/pubsub.publisher` on the topic |
| `bigquery_dataset` | `catalog-demo/gcp-bigquery-dataset` | `roles/bigquery.dataEditor` on the dataset |
| `storage_bucket` | `catalog-demo/gcp-storage-bucket` | `roles/storage.objectUser` on the bucket |

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-cloud-run-service`

| Field | Type | Description |
|---|---|---|
| `project_id` | string | GCP project that owns the service |
| `service_name` | string | Short service name (used in gcloud commands) |
| `service_url` | string | HTTPS URL of the service (`.run.app` domain) |
| `location` | string | GCP region where the service is deployed |
| `latest_ready_revision` | string | Name of the currently-serving revision |
| `runtime_service_account_email` | string | Email of the SA the service runs as |
| `runtime_service_account_member` | string | IAM principal string (`serviceAccount:<email>`) for downstream bindings |

The `runtime_service_account_member` field is designed for downstream bundles (Scheduler, Pub/Sub push) that need to grant `roles/run.invoker` to the Cloud Run service's own identity — or for external callers that need to invoke the service.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `image` | string | `gcr.io/cloudrun/hello` | Container image to deploy. Default is deployable out of the box for testing. |
| `port` | integer | `8080` | Port the container listens on. Must match the process — mismatch causes revision failure. |
| `cpu` | enum | `1` | vCPUs per instance: `1`, `2`, `4`, `8` |
| `memory` | enum | `512Mi` | Memory per instance: `256Mi` through `32Gi` |
| `min_instances` | integer | `0` | Scale-to-zero when 0. Any value above 0 means you pay for idle capacity. |
| `max_instances` | integer | `100` | Cap on autoscaling. Reduce to protect downstream systems from traffic spikes. |
| `ingress` | enum | `internal` | Traffic source restriction: `all`, `internal`, `internal-and-cloud-load-balancing` |
| `allow_unauthenticated` | boolean | `false` | Grant `allUsers` `roles/run.invoker` for public anonymous access |

## Presets

| Preset | Ingress | Min | Max | CPU | Memory | Unauth |
|---|---|---|---|---|---|---|
| Internal | `internal` | 0 | 10 | 1 | 512Mi | false |
| Public API | `all` | 1 | 100 | 2 | 1Gi | true |
| Worker | `internal` | 1 | 50 | 2 | 2Gi | false |

## Compliance

### Hardcoded Controls

| Control | Value | Rationale |
|---|---|---|
| Runtime identity | Landing zone workload SA | All services run as the org-managed SA — no per-service SA proliferation |
| Resource labels | Massdriver default tags | Enforces cost attribution and environment tagging on all revisions |

### Skipped Checks

| Check | Reason |
|---|---|
| `CKV_GCP_102` | Ingress is intentionally configurable. The check fires on any non-internal service without distinguishing IAM controls. Internal-preset services pass this check without the skip; only public-ingress services need it bypassed. |
| `CKV_GCP_103` | Binary Authorization requires a pre-configured attestor policy at the project level. Enabling it per-service without an attestor causes all deployments to fail. Teams requiring binary authorization should enforce it via `google_binary_authorization_policy`. |

## Assumptions

- The landing zone's workload SA is the correct runtime identity for this service. If you need a per-service SA, extend this bundle with an additional `google_service_account` resource and wire it into `template.service_account`.
- VPC connector / direct VPC egress is not provisioned by this bundle. Cloud Run uses Google's serverless infrastructure by default. If you need to reach VPC-private resources (e.g., Cloud SQL without public IP), add a `google_vpc_access_connector` resource and reference it in the template's `vpc_access` block.
- The default image (`gcr.io/cloudrun/hello`) is the Google-managed hello-world container. Replace it with your application image before a real deployment.
