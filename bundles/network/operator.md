---
templating: mustache
---

# Network runbook

## The "Egress Throughput Anomaly" alarm fired — over 1 GB/s is leaving this network

Either a real traffic spike, which the business metrics will confirm within a minute, or data
leaving somewhere it should not. Find the top talkers:

```bash
aws logs start-query \
  --log-group-name "/aws/vpc/flowlogs/{{artifacts.network.id}}" \
  --start-time $(date -u -d '10 minutes ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields srcaddr, dstaddr, bytes
                  | filter action = "ACCEPT"
                  | stats sum(bytes) as total by srcaddr, dstaddr
                  | sort total desc
                  | limit 20'
```

If the destination addresses are unfamiliar, page the security on-call before you throttle
anything — cutting egress destroys the evidence of where it was going.

## The "NAT Port Exhaustion" alarm fired, or outbound connections are being refused

The shared NAT gateway is out of ephemeral ports. Every workload in `{{artifacts.network.id}}`
starts failing to open new outbound connections, all at once, for no reason visible in any single
application's logs.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name ActiveConnectionCount \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) \
  --end-time $(date -u +%FT%TZ) \
  --period 60 --statistics Maximum
```

One workload opening thousands of short-lived connections is the usual cause — a scraper, a
health checker with no keep-alive, or a retry loop. While you find it, add a second NAT gateway
in another availability zone, or give the heaviest workload its own address so it stops sharing
the port pool.

## Connections are being dropped and no application log says why

{{#params.enable_flow_logs}}
Flow logs are on, retained `{{params.flow_log_retention_days}}` days. Rejected traffic is where
misconfigured security groups show up:

```bash
aws logs start-query \
  --log-group-name "/aws/vpc/flowlogs/{{artifacts.network.id}}" \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields srcaddr, dstaddr, dstport
                  | filter action = "REJECT"
                  | stats count() as hits by srcaddr, dstaddr, dstport
                  | sort hits desc
                  | limit 20'
```

A high count on one `dstport` from one `srcaddr` is a rule that was never opened. A low count
spread across many ports is a port scan.
{{/params.enable_flow_logs}}
{{^params.enable_flow_logs}}
Flow logs are off on this network, so there is no record of what was dropped. You cannot answer
this question retroactively. Turn them on, redeploy, and reproduce the failure:

```bash
mass instance deploy {{slug}} -P '.enable_flow_logs = true' -m "troubleshooting dropped connections" -f
```
{{/params.enable_flow_logs}}

## A workload cannot get an IP address — a subnet is full

Count the interfaces already placed in each subnet and compare against the subnet's size:

```bash
{{#artifacts.network.subnets}}
echo -n "{{id}} ({{cidr}}): "
aws ec2 describe-network-interfaces \
  --filters Name=subnet-id,Values={{id}} \
  --query 'length(NetworkInterfaces)' --output text
{{/artifacts.network.subnets}}
```

A /24 holds 251 usable addresses, not 256 — the cloud provider reserves five. Load balancers,
NAT gateways and managed database endpoints each take addresses without appearing as instances,
so a subnet can fill up while looking half empty in the console.

You cannot resize a subnet in place. Add another one in the same availability zone and place new
workloads there.

## Deploy fails because a new subnet CIDR overlaps an existing one

Check the range before you add it. Swap `10.0.3.0/24` for the range you want:

```bash
python3 -c "
from ipaddress import ip_network
net = ip_network('{{artifacts.network.cidr}}')
existing = [{{#artifacts.network.subnets}}'{{cidr}}',{{/artifacts.network.subnets}}]
new = ip_network('10.0.3.0/24')
print('inside the network:', new.subnet_of(net))
print('overlaps an existing subnet:', any(new.overlaps(ip_network(c)) for c in existing))
"
```

You need `inside the network: True` and `overlaps an existing subnet: False`. Anything else and
the deploy will fail, or worse, succeed and break routing for the subnet it collided with.

## Changing `cidr`, or moving this network to a different address range

`cidr` is immutable — it is `{{artifacts.network.cidr}}` and the form will not let you edit it.
Re-IPing means a second network instance and moving every workload across, with real downtime.

Before the cutover:

1. Snapshot every stateful thing attached to this network — databases, persistent volumes.
2. Write down the peering and transit-gateway attachments on `{{artifacts.network.id}}`. They do
   not move with the workloads and each one has to be recreated by hand on the new network.
3. Tell people the window. Expect five to fifteen minutes where inbound traffic fails.

After the cutover, and before you destroy the old network:

- Point DNS at the new network's load balancers.
- Bring up VPN, Direct Connect or ExpressRoute on the new network. If you destroy the old network
  first, you lose the only path you had to reconfigure the far end.
