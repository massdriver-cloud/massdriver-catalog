# gcp-pubsub-topic

Google Cloud Pub/Sub topic with optional dead-letter queue (DLQ). Use this bundle to provision a managed message topic for event-driven workloads — Cloud Run services, Dataflow pipelines, BigQuery subscriptions, and similar.

## Use Cases

- Decoupling producers from consumers in event-driven architectures
- Buffering messages for downstream workers that process at their own pace
- Capturing undeliverable messages in a DLQ for retry or inspection

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_pubsub_topic.main` | Main Pub/Sub topic | Retention and ordering label set at provision time |
| `google_pubsub_topic.dlq` | Dead-letter topic | Created only when `dlq.enabled = true` |

This bundle does NOT create any IAM bindings. Consumer bundles (e.g., `gcp-cloud-run-service`) create their own service accounts and bind the appropriate roles on this topic when connected on the canvas.

## Connections

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id` for resource placement |

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-pubsub-topic`

| Field | Present | Description |
|---|---|---|
| `project_id` | Always | GCP project ID |
| `topic_name` | Always | Main topic resource name |
| `topic_id` | Always | Full topic resource ID |
| `dlq_topic_name` | Only when `dlq.enabled = true` | DLQ topic resource name |
| `dlq_topic_id` | Only when `dlq.enabled = true` | Full DLQ topic resource ID |

Consumer bundles that need to publish or subscribe bind IAM roles using `topic_name` and `project_id` from this artifact. Example pattern in a consumer bundle:

```hcl
resource "google_pubsub_topic_iam_member" "publisher" {
  project = var.pubsub_topic.project_id
  topic   = var.pubsub_topic.topic_name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}
```

## Message Ordering

Message ordering is enforced at the publisher SDK level, not at the topic resource level. The `message_ordering_enabled` parameter writes a label (`message-ordering: enabled|disabled`) on the topic to record operator intent. Publishers must set `enable_message_ordering = true` and use ordering keys in their SDK client. Enabling ordering reduces maximum throughput.

## Compliance

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_83` | CSEK (Customer-Supplied Encryption Keys) skipped across all environments. CSEK requires callers to manage raw AES-256 keys on every API call. Google-managed encryption satisfies encryption-at-rest requirements for the workloads this bundle targets. If CMEK via Cloud KMS is required, use a separate bundle with a KMS connection. |

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- `pubsub.googleapis.com` must be enabled in the landing zone before deploying. Add it to `enabled_apis` in the `gcp-landing-zone` package.
- The `gcp_authentication` credential has `pubsub.admin` or equivalent IAM on the project.

## Presets

| Preset | Retention | DLQ | Max Delivery Attempts | Use Case |
|---|---|---|---|---|
| Low-volume | 7 days | Off | — | Dev or low-traffic topics where DLQ overhead is unnecessary |
| Standard | 7 days | On | 5 | Most production topics; catches undeliverable messages |
| High-throughput | 1 day | On | 10 | High-volume pipelines where shorter retention reduces storage cost |
