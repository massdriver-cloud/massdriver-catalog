---
templating: mustache
---

# AWS Network Runbook

## Alarms

### NAT gateway port exhaustion

The shared NAT gateway is out of ephemeral ports. New outbound connections from private subnets fail for every workload behind it.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --dimensions Name=NatGatewayId,Value={{artifacts.network.nat_gateway_id}} \
  --metric-name ErrorPortAllocation \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) \
  --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Sum
```

Immediate relief: identify and throttle the noisiest workload. If one AZ's traffic consistently saturates the gateway, plan a move to per-AZ NAT gateways; that is a network redesign, not a parameter change.

### ECR interface endpoint unhealthy

If image pulls time out cluster-wide, check the ECR interface endpoints before assuming ECR itself is down:

```bash
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids {{#artifacts.network.ecr_vpc_endpoint_ids}}{{.}} {{/artifacts.network.ecr_vpc_endpoint_ids}} \
  --query 'VpcEndpoints[].{Id:VpcEndpointId,State:State}'
```

If an endpoint shows anything other than `available`, verify the endpoint security group in `{{artifacts.network.vpc_id}}` still allows port 443 from the VPC CIDR. A manual security group edit is the most common cause.

## Common operations

### Confirm S3/ECR traffic is not transiting the NAT

```bash
# NAT gateway bytes processed — should stay flat even under heavy image-pull
# or object-storage load, since that traffic should be using the endpoints.
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --dimensions Name=NatGatewayId,Value={{artifacts.network.nat_gateway_id}} \
  --metric-name BytesOutToDestination \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) \
  --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Sum
```

### Flow log queries

{{#params.enable_flow_logs}}
Flow logs are enabled with {{params.flow_log_retention_days}}-day retention. To find the most-rejected traffic in the last hour, which usually surfaces a misconfigured security group:

```bash
aws logs start-query \
  --log-group-name "/aws/vpc/flowlogs/{{slug}}" \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields srcaddr, dstaddr, dstport
                  | filter action = "REJECT"
                  | stats count() as hits by srcaddr, dstaddr, dstport
                  | sort hits desc
                  | limit 20'
```
{{/params.enable_flow_logs}}
{{^params.enable_flow_logs}}
Flow logs are disabled on this network. Traffic that occurred before enabling them cannot be queried retroactively; enable the parameter and redeploy to begin capture.
{{/params.enable_flow_logs}}

## Disaster recovery

The CIDR (`{{params.cidr}}`) and AZ count are immutable. To re-IP or add capacity, deploy a new network instance, migrate every dependent bundle to it, then decommission this one.

Before migrating:

1. Snapshot every dependent stateful resource (databases, cache).
2. Note anything with a hardcoded reference to `{{artifacts.network.vpc_id}}` outside of Massdriver (peering, VPN, manual security group rules).
3. Schedule a cutover window; expect a few minutes of disruption while the cluster's ingress load balancer and stateful connections re-establish.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-vpc/operator.md
