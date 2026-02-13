# aws-vpc Improvements

Security improvements identified by Checkov during deployment.

## VPC Hardening

- [ ] **HIGH** - **CKV2_AWS_12** - Restrict default security group
  - Add `aws_default_security_group` resource with no ingress/egress rules
  - Prevents accidental use of default SG, forces explicit security group usage

- [ ] **MEDIUM** - **CKV2_AWS_11** - Enable VPC flow logging
  - Add `aws_flow_log` resource with CloudWatch log group
  - Essential for network security auditing and troubleshooting
  - Add param for retention period (default 14 days)

## Subnet Improvements

- [x] **IGNORE** - **CKV_AWS_130** - Public IP assignment on public subnets
  - Intentional behavior - public subnets need public IPs for internet-facing resources
  - Private subnets correctly have `map_public_ip_on_launch = false`
  - This is the correct network design pattern

## General Improvements

- [ ] **MEDIUM** - Add NAT Gateway for private subnet internet access
  - Private subnets currently have no internet access
  - Required for: package updates, API calls, pulling container images
  - Add as optional param (NAT Gateways have ~$32/month cost per AZ)

- [x] **IGNORE** - Add VPC endpoints for AWS services
  - Optimization for reducing data transfer costs
  - Not essential for functionality
  - Can add later as cost optimization feature

---

## Summary

| Priority | Count |
|----------|-------|
| **HIGH** | 1 |
| **MEDIUM** | 2 |
| **IGNORE** | 2 |
