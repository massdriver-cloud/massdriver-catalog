---
templating: mustache
---

# GCP Pub/Sub Topic — Operator Runbook

## Non-obvious constraints

**Topic name is immutable.** To rename a topic: decommission this package, recreate it with the new name, and update all consumer subscriptions. Plan a maintenance window.

**Message retention changes are safe in-place.** Updating `message_retention_duration` applies without disruption. In-flight messages are not affected.

**Enabling DLQ after-the-fact does not update existing subscriptions.** When you enable the DLQ on an existing topic, Terraform creates the DLQ topic — but existing consumer subscriptions do not automatically gain a dead-letter policy. Consumer bundles must be updated separately to reference the new DLQ topic.

**Disabling DLQ destroys the DLQ topic.** Any consumer subscriptions that have a dead-letter policy pointing to the old DLQ topic will fail to deliver dead letters after the destroy. Remove dead-letter policies from consumer subscriptions before disabling the DLQ here.

**Message ordering on the topic is not enforcement.** Setting ordering on the topic is a configuration label. Publishers must also set `enable_message_ordering = true` in their SDK client and pass an ordering key on every publish call. Without ordering keys from publishers, messages are not ordered regardless of the topic setting.

**`max_delivery_attempts` is enforced at the subscription, not the topic.** This bundle provisions the DLQ topic. The delivery attempt limit lives on the consumer's subscription (managed by the consumer bundle). If messages aren't reaching the DLQ, check the consumer subscription's dead-letter policy first.

## Troubleshooting

**Messages not flowing to DLQ.**
Check that the consumer subscription has a dead-letter policy referencing `{{artifacts.pubsub_topic.dlq_topic_name}}`:
```bash
gcloud pubsub subscriptions describe <subscription-name> \
  --project={{artifacts.pubsub_topic.project_id}} \
  --format="yaml(deadLetterPolicy)"
```
If the field is absent, the consumer bundle is not configured to use the DLQ.

**Deploy fails with "pubsub.googleapis.com has not been used in project."**
Add `pubsub.googleapis.com` to `enabled_apis` in the `gcp-landing-zone` package, redeploy the landing zone, wait ~60 seconds, then retry.

**Publisher permission denied.**
The workload SA needs `roles/pubsub.publisher` on the topic:
```bash
gcloud pubsub topics get-iam-policy {{artifacts.pubsub_topic.topic_name}} \
  --project={{artifacts.pubsub_topic.project_id}}
```

## Day-2 operations

**Changing retention duration:** Update param and redeploy. In-place, no disruption.

**Enabling DLQ on an existing topic:** Set `dlq.enabled = true`, configure `max_delivery_attempts`, redeploy. Then update consumer bundles to add dead-letter policies to their subscriptions pointing to `{{artifacts.pubsub_topic.dlq_topic_name}}`.

**Disabling DLQ:** Remove dead-letter policies from all consumer subscriptions first. Then set `dlq.enabled = false` and redeploy. The DLQ topic is destroyed.

**Renaming the topic:** Destroy this package, recreate with the new name, update all consumers. No in-place rename is possible.

**Pulling messages from the DLQ to inspect failures.**
A subscription on the DLQ topic is required (managed by a consumer bundle). If one exists:
```bash
gcloud pubsub subscriptions pull <dlq-subscription-name> \
  --project={{artifacts.pubsub_topic.project_id}} \
  --limit=10 \
  --auto-ack
```

## Useful commands

```bash
# Describe the main topic
gcloud pubsub topics describe {{artifacts.pubsub_topic.topic_name}} \
  --project={{artifacts.pubsub_topic.project_id}}

# List subscriptions on the main topic
gcloud pubsub topics list-subscriptions {{artifacts.pubsub_topic.topic_name}} \
  --project={{artifacts.pubsub_topic.project_id}}

{{#artifacts.pubsub_topic.dlq_topic_name}}
# Describe the DLQ topic
gcloud pubsub topics describe {{artifacts.pubsub_topic.dlq_topic_name}} \
  --project={{artifacts.pubsub_topic.project_id}}

# List subscriptions on the DLQ topic
gcloud pubsub topics list-subscriptions {{artifacts.pubsub_topic.dlq_topic_name}} \
  --project={{artifacts.pubsub_topic.project_id}}
{{/artifacts.pubsub_topic.dlq_topic_name}}

# Check IAM on the main topic
gcloud pubsub topics get-iam-policy {{artifacts.pubsub_topic.topic_name}} \
  --project={{artifacts.pubsub_topic.project_id}}

# Publish a test message
gcloud pubsub topics publish {{artifacts.pubsub_topic.topic_name}} \
  --project={{artifacts.pubsub_topic.project_id}} \
  --message="test"
```
