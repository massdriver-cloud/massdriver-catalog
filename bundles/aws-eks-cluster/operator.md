---
templating: mustache
---

# EKS Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Cluster ARN | `{{artifacts.cluster.id}}` |
| Kubernetes version | `{{artifacts.cluster.version}}` |
| API server | `{{artifacts.cluster.authentication.cluster.server}}` |
| Public endpoint | `{{params.public_api_endpoint}}` |

## Getting kubectl access

The region is the 4th field of the cluster ARN above (`arn:aws:eks:REGION:...`).

```bash
aws eks update-kubeconfig --name {{artifacts.cluster.name}} --region <region-from-arn>
kubectl get nodes
```

If `update-kubeconfig` works but `kubectl` times out, check `params.public_api_endpoint` above — when it's `false`, the API server is only reachable from inside the VPC (VPN or bastion). That's by design in production.

---

## Active alarms — what they mean

### Control Plane Storage Nearly Full

The cluster's internal database (etcd) is past 6 GiB of its hard 8 GiB limit. At 8 GiB the cluster goes **read-only** — no new deploys, no scaling. Something is creating objects far faster than it deletes them.

```bash
# The usual suspects: piles of dead ReplicaSets, Jobs, and Events
kubectl get replicasets -A --no-headers | awk '$2==0' | wc -l
kubectl get jobs -A --no-headers | wc -l

# Clean up finished ReplicaSets (deployments keep 10 by default; a hot CI loop can leave thousands)
kubectl get deploy -A -o name | head
```

**Fix now:** delete completed Jobs and zero-replica ReplicaSets in the noisiest namespaces.
**Fix later:** set `revisionHistoryLimit` on busy Deployments and `ttlSecondsAfterFinished` on Jobs.

## "Nodes are NotReady"

1. See what the node itself says:

   ```bash
   kubectl get nodes
   kubectl describe node <node-name> | grep -A5 Conditions
   ```

   `MemoryPressure` / `DiskPressure` means workloads outgrew the node size — bump `node_instance_size` and redeploy.

2. If nodes are missing entirely, ask the node group what went wrong:

   ```bash
   aws eks describe-nodegroup --cluster-name {{artifacts.cluster.name}} \
     --nodegroup-name {{artifacts.cluster.name}} \
     --query 'nodegroup.health.issues'
   ```

   `Ec2SubnetInvalidConfiguration` or IP-related issues mean the subnets are out of addresses — see the VPC runbook.

## "Pods can't pull images" (`ImagePullBackOff`)

Nodes run on private subnets. If the connected VPC has `nat_gateway: none`, they have **no path to the internet or to ECR** — image pulls will hang, then fail. Check the VPC instance's `nat_gateway` parameter first; this is the most common cause in dev.

If NAT is fine:

```bash
kubectl describe pod <pod-name> | grep -A3 Events
```

- `401 Unauthorized` on a private registry → the registry credential secret is wrong or missing in that namespace.
- `not found` → the tag was never pushed; check the CI job that builds the image.

## "We need more (or bigger) nodes"

- More pods overall → raise `max_nodes` and redeploy. The autoscaler owns the live count; deploys never scale it down.
- Individual pods pending with `Insufficient cpu/memory` → the nodes are too small. Bump `node_instance_size`; EKS replaces nodes one at a time and moves workloads over.
