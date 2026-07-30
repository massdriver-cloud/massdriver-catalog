---
templating: mustache
---

# Queues Runbook

> **Templating context:** `slug`, `params`. Per-queue detail lives on each named `queue` resource this instance emits — check the instance panel for `{{slug}}` to pick a specific queue.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Queue count | {{params.queues.length}} |

### Configured queues

{{#params.queues}}
- **{{name}}** — DLQ: `{{enable_dlq}}`{{#enable_dlq}} (max receives: `{{max_receive_count}}`){{/enable_dlq}}, visibility timeout `{{visibility_timeout_seconds}}s`, retention `{{message_retention_seconds}}s`
{{/params.queues}}

---

## Active alarms — what they mean

### Queue depth growing / consumer falling behind

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/SQS --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=<real-queue-name> \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Maximum
```

Check the consuming app's pod count and error logs first — a growing queue almost always means the consumer is down, crash-looping, or too slow, not that the queue itself is unhealthy.

### Messages landing in the dead-letter queue

```bash
aws sqs get-queue-attributes \
  --queue-url <dlq-url> --attribute-names ApproximateNumberOfMessages
```

Peek at a few without deleting them:

```bash
aws sqs receive-message --queue-url <dlq-url> --max-number-of-messages 5 --visibility-timeout 0
```

Once you've fixed the underlying processing bug, redrive them back to the main queue (SQS console → DLQ → "Start DLQ redrive"), or reprocess manually.

---

## Common operations

### Purge a queue (careful — deletes everything in flight)

```bash
aws sqs purge-queue --queue-url <queue-url>
```

### Send a test message

```bash
aws sqs send-message --queue-url <queue-url> --message-body '{"test": true}'
```

---

## Disaster recovery

Queues don't hold data at rest the way a database does — a lost queue means in-flight messages are gone, not historical data. The real risk is a misconfigured redrive policy silently dropping messages after `max_receive_count` retries with no dead-letter queue to catch them — double check `enable_dlq` is on for anything where a lost message matters.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-sqs-queues/operator.md
