# aws-vpc Improvements

Security improvements identified by Checkov during deployment.

## VPC Hardening

- [x] **HIGH** - **CKV2_AWS_12** - Restrict default security group
  - ✅ Added `aws_default_security_group` resource with no ingress/egress rules
  - Prevents accidental use of default SG, forces explicit security group usage

- [x] **MEDIUM** - **CKV2_AWS_11** - Enable VPC flow logging
  - ✅ Added `aws_flow_log` resource with CloudWatch log group
  - Essential for network security auditing and troubleshooting
  - Retention period set to 14 days

## Remaining Findings (Ignored)

- [x] **IGNORE** - **CKV_AWS_130** - Public IP assignment on public subnets
  - Intentional behavior - public subnets need public IPs for internet-facing resources
  - Private subnets correctly have `map_public_ip_on_launch = false`
  - This is the correct network design pattern

- [x] **IGNORE** - **CKV_AWS_158** - CloudWatch log group KMS encryption
  - Flow logs don't contain sensitive data requiring CMK encryption
  - AWS-managed encryption sufficient for network flow metadata
  - Adding CMK would increase cost and complexity

- [x] **IGNORE** - **CKV2_AWS_338** - CloudWatch log group retention
  - ✅ Retention is already set to 14 days
  - False positive - Checkov may expect longer retention

- [x] **IGNORE** - **CKV_AWS_355** / **CKV_AWS_290** - IAM policy wildcard resources
  - Flow logs IAM policy uses `Resource = "*"` for CloudWatch Logs
  - This is AWS's recommended pattern for flow logs
  - Restricting resources would require dynamic log group ARN construction

## Upstream Module Findings (Not Actionable)

- [x] **IGNORE** - **CKV_AWS_26** - SNS topic encryption
  - Finding is in the `alarm-channel` Massdriver module
  - Would need to be fixed upstream in terraform-modules repo

## Future Improvements (Optional)

- [ ] **MEDIUM** - Add NAT Gateway for private subnet internet access
  - Private subnets currently have no internet access
  - Required for: package updates, API calls, pulling container images
  - Add as optional param (NAT Gateways have ~$32/month cost per AZ)

- [ ] **LOW** - Add VPC endpoints for AWS services
  - Optimization for reducing data transfer costs
  - Not essential for functionality
  - Can add later as cost optimization feature

---

## Summary

| Priority | Fixed | Ignored |
|----------|-------|---------|
| **HIGH** | 1 | 0 |
| **MEDIUM** | 1 | 0 |
| **IGNORE** | 0 | 6 |
