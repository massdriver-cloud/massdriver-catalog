---
templating: mustache
---

# VPC Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| VPC ID | `{{artifacts.network.vpc_id}}` |
| CIDR | `{{artifacts.network.cidr}}` |
| Region | `{{artifacts.network.region}}` |
| NAT | `{{params.nat_gateway}}` |
| Flow logs | `{{params.enable_flow_logs}}` |

### Subnets

| ID | CIDR | Tier | AZ |
|----|------|------|----|
{{#artifacts.network.subnets}}
| `{{id}}` | `{{cidr}}` | `{{tier}}` | `{{availability_zone}}` |
{{/artifacts.network.subnets}}

---

## Active alarms — what they mean

### NAT Port Exhaustion

A NAT gateway ran out of source ports — some instance behind it is opening a huge number of connections to a single destination (often a misbehaving retry loop or a crypto-mining compromise).

```bash
# Which private IPs are the top talkers through this NAT right now?
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values={{artifacts.network.vpc_id}}" \
  --query 'NatGateways[].NatGatewayId' --output text

# If flow logs are on, find the top connection-openers in the last 10 minutes
aws logs start-query \
  --log-group-name "/vpc/{{slug}}/flow-logs" \
  --start-time $(date -v-10M +%s) --end-time $(date +%s) \
  --query-string 'fields srcaddr, dstaddr | filter action = "ACCEPT" | stats count(*) as conns by srcaddr, dstaddr | sort conns desc | limit 20'
```

**Fix now:** identify and stop the offending workload, or switch `nat_gateway` to `per_az` to spread load.
**Fix later:** add connection pooling / retry backoff to the offender.

## "Nothing in a private subnet can reach the internet"

1. Check `params.nat_gateway` above — if it's `none`, that's by design. Change the parameter and redeploy.
2. If NAT is enabled, check the gateway's state:

   ```bash
   aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values={{artifacts.network.vpc_id}}"
   ```

   A `failed` state means AWS-side failure — redeploying this instance recreates it.

## "We're running out of IP addresses"

Each AZ's subnets are fixed-size slices of `{{artifacts.network.cidr}}`. You can't grow them in place. Options, cheapest first:

1. Delete unused ENIs (orphaned load balancers and Lambdas hold IPs): `aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values={{artifacts.network.vpc_id}}" "Name=status,Values=available"`
2. Add an AZ (bump `availability_zones`) to get fresh subnets.
3. Stand up a second VPC instance and peer — talk to the platform team first.
