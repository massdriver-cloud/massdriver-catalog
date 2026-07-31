# Changelog

All notable changes to the `aws-sqs-queues` bundle are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this bundle follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-30

### Added
- Real Terraform/OpenTofu: `for_each` over a `queues[]` param list — one deploy provisions a whole named set of SQS queues, each with SSE, an optional dedicated dead-letter queue, and send-only / send-receive IAM policies.
- Emits one `queue` resource per named queue (all under the same `queues` artifact field) so a consuming app links to exactly the queues it needs out of one producing instance.
- Examples covering both a small (5-queue) and heavy (10-queue) queue user.

## [0.0.0] — initial draft
- Bundle scaffold and resource-type wiring only.
