# Changelog

## 0.2.0

- Added gateway endpoints for S3 and DynamoDB, so workloads in private subnets
  can reach those services without a NAT gateway. Both endpoint types are free.

## 0.1.0

Initial release.

- VPC with public and private subnets across two or three availability zones
- Optional NAT gateway for internet access from private subnets, off by default
- VPC flow logs to CloudWatch, encrypted with a dedicated KMS key
- Default security group stripped of all rules
- Publishes a `virtual-network` resource
