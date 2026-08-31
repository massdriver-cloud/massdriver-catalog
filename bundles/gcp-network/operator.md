# Network runbook

## A Cloud SQL bundle fails to deploy with "no matching subnetwork" or a private IP allocation error

Private Service Access hasn't finished peering, or the reserved range is too small.

Check the peering exists and is active:

```bash
gcloud services vpc-peerings list --network={{resources.network.name}} --project={{resources.network.project_id}}
```

If it's missing, `private_service_access_enabled` is off for this instance — turn it on and
redeploy. If it's present but the Cloud SQL deploy still fails with an out-of-range error, the
reserved range (`private_service_access_prefix_length`) is too small for the number of instances
attached to it. A /20 supports roughly 4,000 addresses; each Cloud SQL instance consumes one.
Widening the prefix length after the fact requires deleting and recreating the peering, which
briefly disconnects every private-IP consumer on this network — schedule it like a maintenance
window, not a routine change.

## A Cloud Run service can't reach a private IP (Cloud SQL, Memorystore, an internal load balancer)

Almost always one of three things:

1. The Cloud Run service is deployed in a different region than the connector
   ({{resources.serverless_connector.region}}). A connector only serves workloads in its own
   region — check the Cloud Run service's region matches.
2. The consuming bundle didn't set `vpc_access.connector` to
   `{{resources.serverless_connector.id}}`, or set egress to route only private-range traffic
   and the target IP isn't actually in a private range.
3. A firewall rule on this network is blocking the connector's IP range
   ({{resources.serverless_connector.name}}'s subnet) from reaching the destination. Default VPC
   firewall rules allow all internal traffic — check for a custom rule that narrowed this.

## Deploy fails with a CIDR overlap error

A new subnet or the connector's CIDR overlaps an existing range. GCP validates this at apply
time and refuses the change rather than silently corrupting routing. Pick a range that doesn't
overlap the network CIDR (`{{params.cidr}}`), any existing subnet, or the Private Service Access
reserved range. There's no autofix — recompute the range by hand and redeploy.

## Deploy fails with "API not enabled" for compute, servicenetworking, or vpcaccess

This bundle enables all three APIs itself as part of every deploy. If this error still surfaces,
the service account's IAM role doesn't include `serviceusage.services.enable` — it needs
`roles/editor` or `roles/serviceusage.serviceUsageAdmin` at minimum on the project.

## The connector won't scale up under load, or shows degraded throughput

Each connector instance handles roughly 100 Mbps. If `connector_max_instances` is maxed out and
traffic still exceeds capacity, either raise `connector_max_instances` or move
`connector_machine_type` from `e2-micro` to `e2-standard-4` — a machine type change requires
recreating the connector, which briefly interrupts any Cloud Run service currently using it.

## Deleting or shrinking this network

Every application-tier bundle connected to this network's subnets, Private Service Access
peering, or Serverless VPC connector loses connectivity the moment those resources change.
Before destroying this instance or removing a subnet, confirm nothing is still connected:

```bash
gcloud compute networks subnets list --network={{resources.network.name}} --project={{resources.network.project_id}}
```

Cloud SQL instances using the Private Service Access peering cannot be moved to a new peering
without a maintenance window — plan deletions accordingly, not as an emergency rollback.
