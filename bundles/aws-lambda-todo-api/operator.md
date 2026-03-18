---
templating: mustache
---

# TODO API (AWS Lambda) — Operator Notes

**Package:** `{{slug}}`

## API Endpoint

The API Gateway URL is published in the `api` artifact under `service_url`:

```
{{artifacts.api.service_url}}
```

## curl Examples

```bash
BASE_URL="{{artifacts.api.service_url}}"

# List all TODOs
curl "$BASE_URL/todos"

# Create a TODO
curl -X POST "$BASE_URL/todos" \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy groceries"}'

# Get a single TODO by ID
curl "$BASE_URL/todos/{id}"

# Update a TODO
curl -X PUT "$BASE_URL/todos/{id}" \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'

# Delete a TODO
curl -X DELETE "$BASE_URL/todos/{id}"
```

## Configuration

**Memory:** `{{params.lambda_memory_mb}}` MB

**Timeout:** `{{params.lambda_timeout_sec}}` seconds

**Log Retention:** `{{params.log_retention_days}}` days

**Region:** `{{params.region}}`

## Architecture Overview

This bundle provisions:

- **AWS Lambda** — Node.js 22.x function, deployed from an S3 zip package
- **API Gateway HTTP API (v2)** — Proxy integration, free `*.execute-api.*.amazonaws.com` endpoint
- **CloudWatch Log Groups** — Separate groups for Lambda and API Gateway access logs
- **IAM Execution Role** — Least-privilege role with the DynamoDB policy selected at deploy time

No Route 53, no custom domain, no VPC required.

## DynamoDB Policy Selection

The `dynamodb_policy` parameter controls which IAM policy is attached to the Lambda execution role. The available options come from the connected DynamoDB table artifact:

- **Read Only** — GetItem, BatchGetItem, Query, Scan, DescribeTable
- **Read / Write** — All read operations plus PutItem, UpdateItem, DeleteItem, BatchWriteItem

The TODO API requires **Read / Write** access to function correctly.

## Compliance Mutes

| Check | Reason |
|-------|--------|
| CKV_AWS_117 | Serverless public REST API — VPC placement not appropriate |
| CKV_AWS_50 | X-Ray optional — not required for this tier |
| CKV_AWS_116 | Synchronous API Gateway invocation — DLQ not applicable |
| CKV_AWS_272 | Code signing — S3-controlled deployment, signing overhead not warranted |
