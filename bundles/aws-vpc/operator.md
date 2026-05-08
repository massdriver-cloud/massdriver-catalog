---
templating: mustache
---

# AWS VPC — Operator Runbook

- **Instance:** `{{id}}`
- **VPC ID:** {{#artifacts.vpc}}`{{artifacts.vpc.id}}`{{/artifacts.vpc}}

## Connect the AWS CLI to this account

```bash
aws sts assume-role \
  --role-arn <iam-role-arn-from-platform> \
  --role-session-name {{id}} \
  --external-id <external-id>
```

## Inspect the VPC

```bash
aws ec2 describe-vpcs \
  --region {{params.region}} \
  {{#artifacts.vpc}}--vpc-ids {{artifacts.vpc.id}}{{/artifacts.vpc}}

aws ec2 describe-subnets \
  --region {{params.region}} \
  --filters Name=vpc-id,Values={{#artifacts.vpc}}{{artifacts.vpc.id}}{{/artifacts.vpc}}

aws ec2 describe-route-tables \
  --region {{params.region}} \
  --filters Name=vpc-id,Values={{#artifacts.vpc}}{{artifacts.vpc.id}}{{/artifacts.vpc}}

aws ec2 describe-nat-gateways \
  --region {{params.region}} \
  --filter Name=vpc-id,Values={{#artifacts.vpc}}{{artifacts.vpc.id}}{{/artifacts.vpc}}
```

## Outbound traffic from private subnets is failing

1. Confirm `nat_gateway_mode` is not `none`. Without a NAT Gateway, private subnets have no path to the internet.
2. With `single`, NAT lives in one AZ. If that AZ is impaired, every private subnet in the VPC loses outbound. Switch to `per-az` and redeploy.
3. The route table for the affected subnet must have a `0.0.0.0/0` route pointing at the NAT.

```bash
aws ec2 describe-nat-gateways \
  --region {{params.region}} \
  --filter Name=vpc-id,Values={{#artifacts.vpc}}{{artifacts.vpc.id}}{{/artifacts.vpc}} \
  --query 'NatGateways[].{Id:NatGatewayId,State:State,Subnet:SubnetId}'

aws ec2 describe-route-tables \
  --region {{params.region}} \
  --filters Name=vpc-id,Values={{#artifacts.vpc}}{{artifacts.vpc.id}}{{/artifacts.vpc}} \
  --query 'RouteTables[].{Id:RouteTableId,Routes:Routes}'
```

## Investigate traffic with VPC Flow Logs

`enable_flow_logs` is currently `{{params.enable_flow_logs}}`. When enabled, flow logs are delivered to CloudWatch under `/aws/vpc/flow-log/*`.

```bash
# Filter for rejected packets in the last hour
aws logs filter-log-events \
  --region {{params.region}} \
  --log-group-name "/aws/vpc/flow-log/{{params.region}}" \
  --start-time $(date -v-1H +%s000) \
  --filter-pattern '"REJECT"'

# Top source IPs being rejected
aws logs filter-log-events \
  --region {{params.region}} \
  --log-group-name "/aws/vpc/flow-log/{{params.region}}" \
  --start-time $(date -v-1H +%s000) \
  --filter-pattern '"REJECT"' \
  --query 'events[].message' --output text | awk '{print $4}' | sort | uniq -c | sort -rn | head
```

## Known constraints

- `cidr` is immutable. CIDR overlap with a peered VPC requires provisioning a new VPC and migrating workloads.
- `enable_dns_hostnames` defaults to `true`. RDS, EKS, and other services that depend on internal DNS require it on. If it was overridden to `false`, downstream resolution will silently break.
- `availability_zone_count` is immutable after the first deploy. Increasing it requires a new VPC.
- Flow logs only capture metadata (5-tuple, action, bytes). They do not include packet payloads.
