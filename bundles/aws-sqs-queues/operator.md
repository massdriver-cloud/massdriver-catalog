---
templating: mustache
---

# Queues Runbook

Per-queue detail (URL, ARN, DLQ) lives on each named `queue` resource this instance emits; check the instance panel for `{{slug}}` to pick a specific queue.

## Alarms

### Queue depth growing

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/SQS --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=<real-queue-name> \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Maximum
```

Check the consuming app's pod count and error logs first. A growing queue almost always means the consumer is down, crash-looping, or too slow, not that the queue itself is unhealthy.

### Messages landing in the dead-letter queue

```bash
aws sqs get-queue-attributes \
  --queue-url <dlq-url> --attribute-names ApproximateNumberOfMessages
```

Inspect a few without deleting them:

```bash
aws sqs receive-message --queue-url <dlq-url> --max-number-of-messages 5 --visibility-timeout 0
```

After fixing the underlying processing bug, redrive them back to the main queue (SQS console → DLQ → "Start DLQ redrive"), or reprocess manually.

## Common operations

### Purge a queue

Deletes every message in the queue, including in-flight messages.

```bash
aws sqs purge-queue --queue-url <queue-url>
```

### Send a test message

```bash
aws sqs send-message --queue-url <queue-url> --message-body '{"test": true}'
```

## Disaster recovery

Queues hold in-flight messages, not data at rest; losing a queue loses whatever was in it at the time, not history. The main failure mode is a queue without a dead-letter queue silently dropping messages after `max_receive_count` retries. Verify `enable_dlq` is on for any queue where a lost message matters.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-sqs-queues/operator.md
