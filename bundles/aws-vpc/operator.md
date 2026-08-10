---
templating: mustache
---

# AWS VPC Runbook

{{#resources.network}}

## Functions in this network cannot reach the internet

Symptom: a Lambda attached to this network times out calling an external API, but the same
code works when detached from the network.

A private subnet has no route to the internet unless a NAT gateway exists. Check whether one
is running:

```bash
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values={{resources.network.id}}" \
  --query 'NatGateways[].{Id:NatGatewayId,State:State,Subnet:SubnetId}' \
  --output table
```

If that returns nothing, set **Allow Internet Access from Private Subnets** to true and
redeploy. If a gateway exists but is not `available`, it is still provisioning — NAT gateways
take two to three minutes.

If a gateway is available and traffic still fails, confirm the private route tables actually
point at it:

```bash
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values={{resources.network.id}}" \
  --query 'RouteTables[].{Id:RouteTableId,Routes:Routes[?DestinationCidrBlock==`0.0.0.0/0`].[GatewayId,NatGatewayId]}' \
  --output json
```

## Ran out of IP addresses

Symptom: new resources fail to launch with `InsufficientFreeAddressesInSubnet`.

Lambda consumes an elastic network interface per concurrent execution scaling unit, and those
eat subnet addresses. Check what is left:

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values={{resources.network.id}}" \
  --query 'Subnets[].{Id:SubnetId,AZ:AvailabilityZone,Free:AvailableIpAddressCount,Cidr:CidrBlock}' \
  --output table
```

The address range is fixed at creation and subnets are carved from it, so you cannot widen a
subnet in place. Options, cheapest first: reduce Lambda reserved concurrency; add a third
availability zone to spread the load; or build a new network on a larger range and migrate.

## Deploy fails with a CIDR conflict

Symptom: `InvalidSubnet.Conflict` or `InvalidVpc.Range` during provision.

The address range overlaps something that already exists, or the range is too small to carve
into the requested number of zones. This bundle splits the range into sixteen blocks, so a
`/24` leaves each subnet only sixteen addresses. Use a `/16` unless you have a specific reason
not to.

## Flow logs are empty

Symptom: the log group exists but has no streams.

Flow logs batch on the aggregation interval, which is set to ten minutes here — wait that long
after traffic before concluding anything is wrong. Then check the log group:

```bash
aws logs describe-log-streams \
  --log-group-name "/aws/vpc-flow-log/{{id}}" \
  --order-by LastEventTime --descending --max-items 5
```

If the group is missing entirely, the deploy did not finish. If the group exists and stays
empty for over fifteen minutes with traffic flowing, the flow log's IAM role likely lost its
CloudWatch write permission — redeploy to restore it.

## Deleting this network fails

Symptom: decommission hangs or fails with `DependencyViolation`.

Something outside this bundle is still attached — usually a Lambda's network interfaces, which
AWS detaches lazily and can take up to twenty minutes to release. Find the stragglers:

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values={{resources.network.id}}" \
  --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Status:Status,Desc:Description}' \
  --output table
```

Decommission the workloads that own those interfaces first, wait for the interfaces to
disappear, then retry.

{{/resources.network}}

{{^resources.network}}

This network has not been deployed yet. Deploy it, then return here for operational
procedures.

{{/resources.network}}
