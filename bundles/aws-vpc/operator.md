---
templating: mustache
---

# AWS Network Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| VPC ID | `{{artifacts.network.vpc_id}}` |
| Region | `{{artifacts.network.region}}` |
| CIDR | `{{artifacts.network.cidr}}` |
| NAT gateway | `{{artifacts.network.nat_gateway_id}}` |
| Flow logs | `{{params.enable_flow_logs}}` (retention: `{{params.flow_log_retention_days}}d`) |

### Subnets

| ID | CIDR | Type | AZ |
|----|------|------|----|
{{#artifacts.network.subnets}}
| `{{id}}` | `{{cidr}}` | `{{type}}` | `{{availability_zone}}` |
{{/artifacts.network.subnets}}

---

## Active alarms — what they mean

### NAT gateway port exhaustion

The shared NAT gateway (`{{artifacts.network.nat_gateway_id}}`) is out of ephemeral ports. New outbound connections from private subnets start failing for every workload behind it — cluster nodes, apps pulling from third-party APIs, everything.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --dimensions Name=NatGatewayId,Value={{artifacts.network.nat_gateway_id}} \
  --metric-name ErrorPortAllocation \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) \
  --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Sum
```

Immediate relief: identify and throttle the noisiest workload. Longer term: this bundle is single-NAT by design to keep cost down — if one AZ's traffic is consistently saturating it, that's a signal to split the network bundle per-AZ NAT, which is a real re-architecture, not a param flip.

### Interface endpoint (ECR) unhealthy

If image pulls start timing out cluster-wide, check the ECR interface endpoints before assuming it's ECR itself:

```bash
aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids {{#artifacts.network.ecr_vpc_endpoint_ids}}{{.}} {{/artifacts.network.ecr_vpc_endpoint_ids}} \
  --query 'VpcEndpoints[].{Id:VpcEndpointId,State:State}'
```

If an endpoint shows anything other than `available`, check the endpoint security group (`{{artifacts.network.vpc_id}}`) still allows port 443 from the VPC CIDR — a manual security group edit is the most common cause.

---

## Common operations

### Confirm S3/ECR traffic isn't hitting the NAT

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
Flow logs are enabled (retention `{{params.flow_log_retention_days}}d`). Useful starter query — most-rejected traffic in the last hour, which usually surfaces a misconfigured security group:

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
**Flow logs are disabled on this network.** Turn them on and redeploy before you need to troubleshoot connectivity or investigate a security incident — you can't retroactively see traffic that already happened.
{{/params.enable_flow_logs}}

---

## Disaster recovery

This bundle's CIDR (`{{params.cidr}}`) and AZ count are **immutable**. To re-IP or add capacity, deploy a new network instance, migrate every dependent bundle to point at it, then decommission this one.

### Pre-migration checklist

1. Snapshot every dependent resource (databases, cache).
2. Note anything with a hardcoded reference to `{{artifacts.network.vpc_id}}` outside of Massdriver (peering, VPN, manual security group rules).
3. Communicate the cutover window — expect a few minutes of disruption while the cluster's ingress load balancer and any stateful connections re-establish.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-vpc/operator.md
