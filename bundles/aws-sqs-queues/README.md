# Queues

Provisions a named set of SQS queues for background work: sending email, resizing images, transcoding video, or anything else an app hands off for asynchronous processing. Emits one `queue` resource per entry, so an app that needs ten queues is one deploy with ten entries, not ten deploys.

## What it provisions, per queue

- An SQS queue, encrypted at rest.
- An optional dead-letter queue with a configurable receive limit, so repeatedly failing messages are set aside instead of retried indefinitely.
- Two IAM access policies, send-only and send-receive, that consuming apps attach through their service account's IAM role. No shared access keys.

## Parameters worth knowing

- Entries in the `queues` list can be added or removed on redeploy; the remaining queues are untouched.
- `visibility_timeout_seconds` should exceed the consumer's worst-case processing time, or messages will be redelivered while still being processed.
- Without a dead-letter queue, a message that keeps failing is retried until retention expires and is then dropped.

## Operational notes

- `src/main.tf` fans each entry in the `queues` list out into an `aws_sqs_queue` (plus its dead-letter queue, if enabled) and the scoped IAM policies.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
