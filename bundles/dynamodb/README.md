# dynamodb

AWS DynamoDB table with encryption at rest, point-in-time recovery, and deletion protection hardcoded for compliance.

## Overview

Provisions a single DynamoDB table with configurable key schema, billing mode, and optional streams. Produces two IAM policies (read-only and read/write) as part of its artifact so downstream bundles can request scoped access without managing IAM themselves.

### Compliance (hardcoded)

- Encryption at rest (AWS-managed KMS)
- Point-in-time recovery enabled
- Deletion protection enabled
- `prevent_destroy` lifecycle guard in Terraform

### Immutable settings

Table name, hash key, range key, and billing mode are all marked `$md.immutable` and protected by `prevent_destroy`. These cannot be changed after initial creation.

## Parameters

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `region` | string | Yes | - | AWS region |
| `table_name` | string | Yes | - | DynamoDB table name |
| `hash_key` | string | Yes | - | Partition key attribute name |
| `hash_key_type` | string | No | `S` | Partition key type (S/N/B) |
| `range_key` | string | No | - | Optional sort key attribute name |
| `range_key_type` | string | No | `S` | Sort key type (S/N/B) |
| `billing_mode` | string | Yes | `PAY_PER_REQUEST` | `PAY_PER_REQUEST` or `PROVISIONED` |
| `read_capacity` | integer | Conditional | 5 | RCUs (only when PROVISIONED) |
| `write_capacity` | integer | Conditional | 5 | WCUs (only when PROVISIONED) |
| `enable_streams` | boolean | No | false | Enable DynamoDB Streams |
| `stream_view_type` | string | No | `NEW_AND_OLD_IMAGES` | Stream record contents |

## Connections

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `aws_authentication` | `aws-catalog/aws-iam-role` | Yes | AWS IAM role for Massdriver to assume |

## Artifacts Produced

| Name | Type | Description |
|------|------|-------------|
| `table` | `aws-catalog/dynamodb` | Table ARN, name, region, stream ARN, and IAM policies |

### Artifact policies

The artifact exposes two IAM policies that downstream bundles can select via `$md.enum`:

| Policy Name | Actions |
|-------------|---------|
| **Read Only** | GetItem, BatchGetItem, Query, Scan, DescribeTable |
| **Read / Write** | All read actions + PutItem, UpdateItem, DeleteItem, BatchWriteItem, ConditionCheckItem |

Consuming bundles reference these via the `policies` field on the `aws-catalog/dynamodb` artifact. See `bundles/aws-lambda-todo-api` for a working example.
