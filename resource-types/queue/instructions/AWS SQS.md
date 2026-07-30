# Importing an existing SQS queue

Use this when you already have an SQS queue and want Massdriver to know about it, instead of provisioning one as part of the `aws-sqs-queues` named set.

## Where to find each field

1. Open the **SQS console** → your queue.
   - `name`: the queue name (this is the logical name apps will reference).
   - `url`: the "URL" field.
   - `arn`: the "ARN" field.
   - `region`: shown in the top-right of the console.
   - `id`: same as the ARN, unless your provider uses a separate internal ID.
2. If this queue has a redrive policy pointing at a dead-letter queue:
   - `dlq_url` / `dlq_arn`: the DLQ's URL and ARN.
3. In the **IAM console**, find (or create) the managed policies you want consumers to be able to attach — typically one scoped to `send`-only and one scoped to `send + receive + delete`.
   - `policies[].id`: each policy's ARN.
   - `policies[].name`: a short label shown in the app bundle's queue-access dropdown.

## Notes

- One `queue` resource represents a single named queue. A producing bundle can emit many of these, one per name in its named set, so an app that uses many queues does not need one deploy per queue.
