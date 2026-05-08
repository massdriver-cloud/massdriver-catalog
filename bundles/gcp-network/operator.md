---
templating: mustache
---

# GCP Network — Operator Runbook

## Non-obvious constraints

**Network name is immutable.** Changing it forces replacement of the entire VPC and all dependent resources (subnets, firewall rules, peerings). Treat it as permanent after first deploy.

**Subnet CIDR is immutable.** GCP does not support in-place CIDR changes. To change it: decommission all resources in the subnet, destroy this package, then reprovision with the new range.

**Subnet region is immutable.** The subnet's region cannot be changed after creation. A region change requires destroy and recreate.

**Deny-all firewall is hardcoded at priority 65534.** This bundle creates a single baseline deny-all ingress rule. No ingress traffic is allowed by default. Workload bundles (Cloud Run, Vertex, etc.) layer their own allow rules at lower priority numbers.

**VPC is global; the subnet is regional.** Cross-region resources can share the VPC but need their own regional subnets — extend the Terraform source if additional subnets are needed.

**Deleting the network fails if anything is still attached.** Terraform will error if VMs, Cloud Run VPC connectors, GKE nodes, or other resources are still using the network. Decommission all dependent packages first.

## Troubleshooting

**Subnet resources fail to delete ("resourceInUseByAnotherResource").**
Something is still attached. Find it:
```bash
gcloud compute networks list-associated-resources {{artifacts.network.network_name}} \
  --project={{artifacts.network.project_id}}
```
Decommission those packages first, then retry destroy.

**Firewall rules not taking effect.**
Rules are evaluated by priority (lowest number wins). Check the full rule list for conflicts:
```bash
gcloud compute firewall-rules list \
  --filter="network:{{artifacts.network.network_name}}" \
  --format="table(name,direction,priority,disabled,sourceRanges,allowed[].map().firewall_rule().list():label=ALLOW,denied[].map().firewall_rule().list():label=DENY)" \
  --sort-by=priority
```

**API quota or "permission denied" on VPC creation.**
Ensure `compute.googleapis.com` is enabled in the landing zone's `enabled_apis`.

## Day-2 operations

**Expanding or changing CIDR:** Not supported in-place. Must destroy and recreate. Decommission all resources in the subnet first.

**Adding subnets:** This bundle provisions one regional subnet. For additional subnets, extend the Terraform source directly.

**VPC peering:** Add a `google_compute_network_peering` resource to the bundle source. Ensure CIDR ranges don't overlap between peered VPCs.

**Querying VPC flow logs:**
Flow logs are stored in Cloud Logging under resource type `gce_subnetwork`. Sampling is 50% at 5-second aggregation intervals.
```bash
gcloud logging read \
  'resource.type="gce_subnetwork" AND resource.labels.subnetwork_name="{{artifacts.network.primary_subnet.name}}"' \
  --project={{artifacts.network.project_id}} \
  --limit=50 \
  --format=json
```

## Useful commands

```bash
# List all firewall rules on this network
gcloud compute firewall-rules list \
  --filter="network:{{artifacts.network.network_name}}" \
  --format="table(name,direction,priority,disabled,sourceRanges,allowed[].map().firewall_rule().list():label=ALLOW,denied[].map().firewall_rule().list():label=DENY)"

# Describe the primary subnet
gcloud compute networks subnets describe {{artifacts.network.primary_subnet.name}} \
  --region={{artifacts.network.region}} \
  --project={{artifacts.network.project_id}}

# Describe the VPC
gcloud compute networks describe {{artifacts.network.network_name}} \
  --project={{artifacts.network.project_id}}

# Tail recent VPC flow logs for this subnet
gcloud logging read \
  'resource.type="gce_subnetwork" AND resource.labels.subnetwork_name="{{artifacts.network.primary_subnet.name}}"' \
  --project={{artifacts.network.project_id}} \
  --limit=20 \
  --format=json
```
