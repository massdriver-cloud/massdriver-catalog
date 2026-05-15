---
templating: mustache
---

# Network Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`. Connections aren't used by this bundle.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Network ID | `{{artifacts.network.id}}` |
| CIDR | `{{artifacts.network.cidr}}` |
| Flow logs | `{{params.enable_flow_logs}}` (retention: `{{params.flow_log_retention_days}}d`) |

### Subnets

| ID | CIDR | Type |
|----|------|------|
{{#artifacts.network.subnets}}
| `{{id}}` | `{{cidr}}` | `{{type}}` |
{{/artifacts.network.subnets}}

---

## Active alarms — what they mean

### Egress Throughput Anomaly

The network is pushing > 1 GB/s outbound. Either a real traffic spike (good news, check business metrics) or data exfiltration.

```bash
# AWS — top talkers in the last 10 minutes via flow logs
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

If destinations look unfamiliar, page the security on-call.

### NAT Port Exhaustion

The shared NAT gateway is out of ephemeral ports. New outbound connections will start failing for everything in `{{artifacts.network.id}}`.

```bash
# Check which subnet's instances are opening the most connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name ActiveConnectionCount \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) \
  --end-time $(date -u +%FT%TZ) \
  --period 60 --statistics Maximum
```

Workarounds while you investigate: add a second NAT in another AZ (or temporarily attach an Elastic IP per heavy workload), then redeploy.

---

## Common operations

### Verify a CIDR doesn't overlap before adding a subnet

```bash
python3 -c "
from ipaddress import ip_network
net = ip_network('{{artifacts.network.cidr}}')
existing = [{{#artifacts.network.subnets}}'{{cidr}}',{{/artifacts.network.subnets}}]
new = ip_network('NEW_SUBNET_CIDR_HERE')
print('subset:', new.subnet_of(net))
print('overlaps:', any(new.overlaps(ip_network(c)) for c in existing))
"
```

### Subnet exhaustion check

```bash
# What % of each subnet's IPs are in use? Run inside the VPC.
{{#artifacts.network.subnets}}
echo -n "{{id}} ({{cidr}}): "
aws ec2 describe-network-interfaces \
  --filters Name=subnet-id,Values={{id}} \
  --query 'length(NetworkInterfaces)' --output text
{{/artifacts.network.subnets}}
```

### Flow log queries

{{#params.enable_flow_logs}}
Flow logs are enabled (retention `{{params.flow_log_retention_days}}d`). Useful starter queries:

```bash
# Most rejected traffic in the last hour — surfaces misconfigured security groups
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
{{/params.enable_flow_logs}}
{{^params.enable_flow_logs}}
**Flow logs are disabled on this network.** Enable them and redeploy if you're troubleshooting connectivity issues.
{{/params.enable_flow_logs}}

---

## Disaster recovery

This bundle's CIDR (`{{params.cidr}}`) is **immutable**. To re-IP, deploy a new network bundle instance, migrate workloads, then decommission this one.

### Pre-migration checklist

1. Snapshot every dependent resource (databases, persistent volumes).
2. Note all peering / transit-gateway attachments on `{{artifacts.network.id}}`.
3. Communicate the cutover window — expect 5–15 min of inbound traffic disruption.

### Post-migration

- Update DNS to point at the new network's load balancers.
- Verify outbound connectivity from a workload in each subnet type (`public`, `private`).
- Re-establish VPN / Direct Connect / ExpressRoute on the new network before destroying the old one.

---

**Edit this runbook:** https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/network/operator.md
