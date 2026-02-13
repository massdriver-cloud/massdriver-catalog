# aws-rds-postgres Improvements

Security improvements identified by Checkov during deployment.

## RDS Instance Hardening

- [x] **HIGH** - **CKV_AWS_293** - Enable deletion protection
  - ✅ Added `deletion_protection` param (default true)
  - Prevents accidental database deletion in production

- [x] **HIGH** - **CKV_AWS_129** - Enable RDS logging
  - ✅ Added `enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]`
  - Essential for debugging, audit trails, and security monitoring

- [x] **HIGH** - **CKV2_AWS_30** - Enable PostgreSQL query logging
  - ✅ Created `aws_db_parameter_group` with logging parameters
  - Required for slow query analysis and security auditing

- [x] **MEDIUM** - **CKV_AWS_118** - Enable enhanced monitoring
  - ✅ Added `monitoring_interval = 60` and IAM role
  - Provides OS-level metrics for performance troubleshooting

- [x] **MEDIUM** - **CKV_AWS_353** - Enable Performance Insights
  - ✅ Added `performance_insights_enabled = true`
  - Free tier available (7 days), essential for query performance analysis

- [x] **LOW** - **CKV2_AWS_60** - Copy tags to snapshots
  - ✅ Added `copy_tags_to_snapshot = true`
  - Ensures backup traceability and cost allocation

- [x] **MEDIUM** - **CKV2_AWS_69** - Encryption in transit
  - ✅ Added `rds.force_ssl = 1` to parameter group
  - Forces all connections to use SSL/TLS encryption

- [x] **LOW** - Add CloudWatch alarms for RDS metrics
  - ✅ CPU utilization alarm added (see `src/alarms.tf`)
  - TODO: Add connection count, storage space alarms

## Remaining Findings (Ignored)

- [x] **IGNORE** - **CKV_AWS_161** - Enable IAM database authentication
  - Many applications don't support IAM auth (requires SDK integration)
  - Standard username/password is more portable across tools
  - Can add as optional param for AWS-native applications

- [x] **IGNORE** - **CKV_AWS_157** - Multi-AZ deployment
  - Intentionally excluded per requirements (no replicas, single instance)
  - Cost optimization for dev/test workloads
  - Can add as optional param for production use cases

## Security Group Improvements

- [x] **IGNORE** - **CKV_AWS_382** - Restrict egress rules
  - RDS needs outbound for: AWS API calls, enhanced monitoring, logs shipping
  - Skip comment added: `# checkov:skip=CKV_AWS_382:RDS requires outbound for AWS API calls, enhanced monitoring, and log shipping`

- [x] **IGNORE** - **CKV2_AWS_5** - Security group attached to resource
  - Skip comment added: `# checkov:skip=CKV2_AWS_5:Security group is attached to RDS instance below`
  - Security group IS attached to RDS instance

## Upstream Module Findings (Not Actionable)

- [x] **IGNORE** - **CKV_AWS_26** - SNS topic encryption
  - Finding is in the `alarm-channel` Massdriver module
  - Would need to be fixed upstream in terraform-modules repo

---

## Summary

| Priority | Fixed | Ignored |
|----------|-------|---------|
| **HIGH** | 3 | 0 |
| **MEDIUM** | 3 | 0 |
| **LOW** | 2 | 0 |
| **IGNORE** | 0 | 5 |
