# gcp-pubsub-topic

Google Cloud Pub/Sub topic with optional dead-letter queue (DLQ). Use this bundle to provision a managed message topic for event-driven workloads — Cloud Run consumers, Dataflow pipelines, BigQuery subscriptions, and similar. The landing zone's workload service account is automatically granted publisher access.

## Purpose

- Provisions a Pub/Sub topic with configurable retention
- Optionally provisions a companion DLQ topic for undeliverable messages
- Grants `roles/pubsub.publisher` to the landing zone's workload service account on the main topic
- Emits a `catalog-demo/gcp-pubsub-topic` artifact so downstream bundles can reference the topic without hard-coding names

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_pubsub_topic.main` | Main Pub/Sub topic | Retention and ordering label set at provision time |
| `google_pubsub_topic.dlq` | Dead-letter topic | Created only when `dlq.enabled = true` |
| `google_pubsub_topic_iam_member.workload_publisher` | IAM binding | Grants `roles/pubsub.publisher` to the landing zone workload SA on the main topic |

## Artifacts Consumed (Connections)

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id` and `workload_identity.service_account_email` for the publisher IAM binding |

## Artifacts Produced

The bundle publishes a `catalog-demo/gcp-pubsub-topic` artifact. DLQ fields are present only when the DLQ is enabled.

| Field | Description | Present |
|---|---|---|
| `project_id` | GCP project ID | Always |
| `topic_name` | Main topic resource name | Always |
| `topic_id` | Full topic resource ID | Always |
| `dlq_topic_name` | DLQ topic resource name | Only when `dlq.enabled = true` |
| `dlq_topic_id` | Full DLQ topic resource ID | Only when `dlq.enabled = true` |

Downstream bundles that need subscriber access should bind `roles/pubsub.subscriber` on the topic or on their own subscription using `topic_name` and `project_id` from this artifact.

## Compliance

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_83` | CSEK (Customer-Supplied Encryption Keys) skipped across all environments. CSEK requires callers to manage raw AES-256 keys on every API call — GCP itself recommends against this for most workloads. Google-managed encryption (default) satisfies encryption-at-rest requirements. If CMEK via Cloud KMS is required, add a `kms_key_name` param and remove this skip. |

### Production gating

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- `pubsub.googleapis.com` must be enabled in the landing zone before deploying this bundle. Add it to `enabled_apis` in the `gcp-landing-zone` package config.
- The `gcp_authentication` credential has `pubsub.admin` or equivalent IAM on the project.
- The landing zone's workload SA is granted publisher access automatically; subscriber access for consumers must be added by the downstream bundle.

## Message Ordering

Message ordering is enforced at the **publisher SDK level**, not at the topic resource level. The `message_ordering_enabled` parameter writes a label (`message-ordering: enabled|disabled`) on the topic to record operator intent. Publishers must explicitly set `enable_message_ordering = true` and use ordering keys when publishing. Enabling ordering reduces maximum throughput per topic.

## Presets

| Preset | Retention | DLQ | Max Delivery Attempts | Use Case |
|---|---|---|---|---|
| Low-volume | 7 days | Off | — | Dev / low-traffic topics where DLQ overhead is unnecessary |
| Standard | 7 days | On | 5 | Most production topics; catches poison-pill messages |
| High-throughput | 1 day | On | 10 | High-volume pipelines where shorter retention reduces storage cost |
