# AWS VPC Runbook

It's 2am. Your VPC is misbehaving. Here's what to check.

## Outbound traffic from private subnets is failing

If pods or instances in private subnets can't reach the internet:

1. Confirm `nat_gateway_mode` isn't `none`. Without a NAT Gateway, private subnets have no path out.
2. If `nat_gateway_mode` is `single`, the NAT lives in one AZ. If that AZ is impaired, all private subnets break. Switch to `per-az` and redeploy.
3. Check that the route table for the affected subnet has a `0.0.0.0/0` route pointing at the NAT.

## Things that look like a VPC bug but aren't

- **RDS or EKS won't resolve internal DNS**: `enable_dns_hostnames` must be `true` (it is by default — confirm it wasn't turned off).
- **CIDR overlap with a peered VPC**: `cidr` is immutable. Cannot fix in place — provision a new VPC and migrate workloads.

## Investigating suspicious traffic

If `enable_flow_logs` is on (default), tail VPC Flow Logs in CloudWatch. Filter by `srcaddr` or `dstaddr` to trace lateral movement, or by `action=REJECT` to see denied packets.
