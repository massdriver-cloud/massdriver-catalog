# Queues

Message queues for background work — anything your app wants to hand off and process later instead of making a user wait for it (sending an email, resizing an image, transcoding a video).

## Why one bundle can hold many queues

Some apps need one queue. Some need ten. Instead of making you deploy this bundle once per queue, you list every queue you need in a single deploy, and each one shows up as its own connectable thing on the canvas — so a heavy queue user isn't ten separate deploys to keep track of, just one deploy with ten entries.

Add or remove an entry and redeploy — the queues you keep are left alone; only what changed gets touched.

## What you get, per queue

- A real SQS queue, encrypted at rest.
- An optional dead-letter queue, for messages that keep failing instead of retrying forever.
- Two ready-made access levels — send-only and send-receive — your app picks up through its own scoped identity, no shared access key.

## Customize it

1. Edit `massdriver.yaml`'s `queues` default/examples to match what you're actually shipping.
2. `src/main.tf` fans every entry in the `queues` list out into a real `aws_sqs_queue` (and, if requested, its dead-letter queue) plus scoped IAM policies — nothing here is a placeholder.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
