# aws-rds-postgres Improvements

Security improvements identified by Checkov during deployment.

## RDS Instance Hardening

- [ ] **HIGH** - **CKV_AWS_293** - Enable deletion protection
  - Add `deletion_protection` param (default true)
  - Prevents accidental database deletion in production

- [ ] **HIGH** - **CKV_AWS_129** - Enable RDS logging
  - Add `enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]`
  - Essential for debugging, audit trails, and security monitoring

- [ ] **HIGH** - **CKV2_AWS_30** - Enable PostgreSQL query logging
  - Create `aws_db_parameter_group` with logging parameters
  - Required for slow query analysis and security auditing

- [ ] **MEDIUM** - **CKV_AWS_118** - Enable enhanced monitoring
  - Add `monitoring_interval` (60 seconds) and create IAM role
  - Provides OS-level metrics for performance troubleshooting

- [ ] **MEDIUM** - **CKV_AWS_353** - Enable Performance Insights
  - Add `performance_insights_enabled = true`
  - Free tier available (7 days), essential for query performance analysis

- [ ] **LOW** - **CKV2_AWS_60** - Copy tags to snapshots
  - Add `copy_tags_to_snapshot = true`
  - Ensures backup traceability and cost allocation

- [ ] **LOW** - Add CloudWatch alarms for RDS metrics
  - CPU utilization, connection count, storage space
  - Use `var.md_metadata.observability.alarm_webhook_url` for notifications

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
  - Restricting to VPC CIDR only could break AWS-managed functionality
  - AWS manages RDS networking; egress restriction adds minimal security value

## General Improvements

- [x] **IGNORE** - Add KMS customer-managed keys for RDS encryption
  - AWS-managed keys sufficient for most use cases
  - Customer-managed adds key rotation complexity
  - Can add as optional param for strict compliance requirements

- [x] **IGNORE** - Add secrets rotation for RDS master password
  - Adds significant complexity (Secrets Manager, Lambda rotation)
  - Master password typically used only for initial admin setup
  - Applications should use dedicated credentials or IAM auth

---

## Summary

| Priority | Count |
|----------|-------|
| **HIGH** | 3 |
| **MEDIUM** | 2 |
| **LOW** | 2 |
| **IGNORE** | 5 |
