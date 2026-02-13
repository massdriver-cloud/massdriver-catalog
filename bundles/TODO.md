# Bundle Improvements

Security and best practice improvements identified by Checkov during deployments.

## aws-rds-postgres

### RDS Instance Hardening

- [ ] **FIX** - **CKV_AWS_129** - Enable RDS logging (error, general, slowquery, postgresql logs)
  - Add `enabled_cloudwatch_logs_exports` parameter
  - Consider making log types configurable via params

- [ ] **FIX** - **CKV_AWS_118** - Enable enhanced monitoring
  - Add `monitoring_interval` and `monitoring_role_arn`
  - Create IAM role for RDS enhanced monitoring

- [x] **IGNORE** - **CKV_AWS_161** - Enable IAM database authentication
  - Many applications don't support IAM auth (requires SDK integration)
  - Standard username/password is more portable
  - Can revisit as optional param later

- [ ] **FIX** - **CKV_AWS_293** - Enable deletion protection
  - Add `deletion_protection` param (default true)
  - Bundle should default to safe production settings

- [ ] **FIX** - **CKV_AWS_353** - Enable Performance Insights
  - Add `performance_insights_enabled = true`
  - Free tier available (7 days retention), very useful for debugging

- [x] **IGNORE** - **CKV_AWS_157** - Multi-AZ deployment
  - Intentionally excluded per requirements (no replicas, single instance)
  - Cost optimization for dev/test workloads
  - Can add as optional param for production use cases

- [ ] **FIX** - **CKV2_AWS_30** - Enable PostgreSQL query logging
  - Create `aws_db_parameter_group` with logging parameters
  - Essential for debugging slow queries and performance tuning

- [ ] **FIX** - **CKV2_AWS_60** - Copy tags to snapshots
  - Add `copy_tags_to_snapshot = true`
  - One-liner fix, ensures backup traceability

### Security Group Improvements

- [x] **IGNORE** - **CKV_AWS_382** - Restrict egress rules
  - RDS needs outbound for: AWS API calls, enhanced monitoring, logs shipping
  - Restricting to VPC CIDR only could break functionality
  - AWS manages RDS networking; egress restriction adds little security value

## aws-vpc

### VPC Hardening

- [ ] **FIX** - **CKV2_AWS_11** - Enable VPC flow logging
  - Add `aws_flow_log` resource
  - Essential for security auditing and troubleshooting
  - Add param for retention period

- [ ] **FIX** - **CKV2_AWS_12** - Restrict default security group
  - Add `aws_default_security_group` resource with no rules
  - Forces explicit security group usage, prevents accidental exposure

### Subnet Improvements

- [x] **IGNORE** - **CKV_AWS_130** - Public IP assignment on public subnets
  - Intentional behavior - public subnets need public IPs for internet-facing resources
  - Private subnets already have `map_public_ip_on_launch = false`
  - This is the correct network design pattern

## General Improvements

- [x] **IGNORE** - Add KMS customer-managed keys for RDS encryption
  - AWS-managed keys are sufficient for most use cases
  - Customer-managed adds key rotation complexity
  - Can add as optional param for compliance requirements

- [ ] **FIX** - Add NAT Gateway to VPC for private subnet internet access
  - Private subnets currently have no internet access
  - Required for: package updates, API calls, pulling container images
  - Add as optional param (NAT Gateways have hourly cost)

- [x] **IGNORE** - Add VPC endpoints for AWS services
  - Optimization for reducing data transfer costs
  - Not essential for functionality
  - Can add later as cost optimization feature

- [ ] **FIX** - Add CloudWatch alarms for RDS metrics
  - CPU utilization, connection count, storage space, replication lag
  - Use `var.md_metadata.observability.alarm_webhook_url` for notifications

- [x] **IGNORE** - Add secrets rotation for RDS master password
  - Adds significant complexity (Secrets Manager, Lambda rotation function)
  - Master password typically used only for initial setup
  - Apps should use IAM auth or app-specific credentials
  - Can add as separate "rds-secrets-rotation" bundle if needed

---

## Summary

| Status | Count |
|--------|-------|
| **FIX** | 10 |
| **IGNORE** | 7 |

### Priority Order

1. `copy_tags_to_snapshot` - trivial one-liner
2. `deletion_protection` - simple param addition
3. `performance_insights_enabled` - simple, free tier available
4. Default security group restriction - simple security win
5. RDS logging + query logging - requires parameter group
6. VPC flow logging - requires log group setup
7. Enhanced monitoring - requires IAM role
8. NAT Gateway - infrastructure cost, make optional
9. CloudWatch alarms - nice to have for observability
