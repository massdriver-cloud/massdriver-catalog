# aws-dynamodb-table Operator Guide

## Overview

This bundle provisions an AWS DynamoDB table with the following compliance settings hardcoded (non-configurable):

| Setting | Value | Checkov Check |
|---|---|---|
| Server-side encryption | Enabled (AWS-managed key) | CKV_AWS_28 |
| Point-in-time recovery | Enabled | CKV2_AWS_16 |
| Deletion protection | Enabled | CKV2_AWS_118 |

## Immutable Fields

The following fields cannot be changed after the table is created without destroying and recreating it:

- **Region** — DynamoDB tables are regional resources
- **Table Name** — changing the name creates a new table
- **Hash Key** and **Hash Key Type** — the partition key is the table's primary identity
- **Range Key** and **Range Key Type** — the sort key is part of the key schema
- **Billing Mode** — changing between PAY_PER_REQUEST and PROVISIONED requires recreation

Massdriver will warn operators before allowing changes to these fields.

## Billing Mode

- **PAY_PER_REQUEST** (default): No capacity planning required. Cost scales linearly with request volume. Best for variable or unpredictable workloads.
- **PROVISIONED**: Fixed capacity in read/write capacity units (RCU/WCU). Lower cost at high or steady throughput. Requires capacity planning.

## IAM Policies

The bundle produces two IAM policies surfaced on the artifact:

| Policy | Permissions |
|---|---|
| Read Only | GetItem, BatchGetItem, Query, Scan, DescribeTable |
| Read / Write | All Read Only + PutItem, UpdateItem, DeleteItem, BatchWriteItem, ConditionCheckItem |

Consumers should attach the appropriate policy to their execution role.

## DynamoDB Streams

When enabled, streams capture a time-ordered sequence of item-level changes. The stream ARN is published on the artifact. Supported view types:

- `KEYS_ONLY` — only key attributes
- `NEW_IMAGE` — the item after modification
- `OLD_IMAGE` — the item before modification
- `NEW_AND_OLD_IMAGES` (default) — both before and after

## Deletion Protection

Deletion protection is hardcoded to `true`. To decommission a table you must first disable deletion protection in the AWS Console or via CLI, then run `mass pkg destroy`.

## Skipped Checks

`CKV_AWS_119` (customer-managed KMS) is intentionally skipped. AWS-managed SSE satisfies most compliance requirements. If your organization requires a customer-managed KMS key, fork this bundle and add the `kms_master_key_id` argument to the `server_side_encryption` block.
