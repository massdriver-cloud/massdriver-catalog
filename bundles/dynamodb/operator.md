# DynamoDB Table — Operator Notes

## Compliance Hardcoded

The following are enforced unconditionally and cannot be disabled through parameters:

| Check | Control | Implementation |
|-------|---------|----------------|
| CKV_AWS_28 | Point-in-Time Recovery | `point_in_time_recovery { enabled = true }` |
| CKV_AWS_119 | Encryption at Rest (AWS-managed key) | `server_side_encryption { enabled = true }` |
| CKV_AWS_341 | Deletion Protection | `deletion_protection_enabled = true` |

## Immutable Fields

The following params are marked `$md.immutable: true` because changing them would require destroying and recreating the table (with potential data loss):

- `table_name` — renaming creates a new table
- `hash_key` / `hash_key_type` — partition key is fixed at creation
- `range_key` / `range_key_type` — sort key is fixed at creation
- `billing_mode` — switching modes requires table replacement

## Deletion Protection

Because `deletion_protection_enabled = true` is hardcoded, you cannot delete the table via Terraform directly. To decommission:

1. Temporarily set `deletion_protection_enabled = false` and apply
2. Then run `terraform destroy`

Or use the AWS console to disable deletion protection first.

## IAM Policies Published

The artifact exposes two IAM policy ARNs:

- **Read Only** — GetItem, BatchGetItem, Query, Scan, DescribeTable
- **Read / Write** — All read operations plus PutItem, UpdateItem, DeleteItem, BatchWriteItem, ConditionCheckItem

Applications connecting to this table receive one of these policy ARNs to attach to their execution role.
