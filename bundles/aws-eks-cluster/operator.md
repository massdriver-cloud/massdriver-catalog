---
templating: mustache
---

# AWS Kubernetes Cluster Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Cluster name | `{{artifacts.cluster.cluster_name}}` |
| Region | `{{artifacts.cluster.region}}` |
| Kubernetes version | `{{params.cluster_version}}` |
| Node size / count | `{{params.node_instance_size}}` × (`{{params.node_min_size}}`–`{{params.node_max_size}}`, desired `{{params.node_desired_size}}`) |
| Public API endpoint | `{{params.endpoint_public_access}}` |
| Ingress cert configured | `{{artifacts.cluster.ingress_certificate_arn}}` |

---

## Getting kubectl access

```bash
aws eks update-kubeconfig \
  --name {{artifacts.cluster.cluster_name}} \
  --region {{artifacts.cluster.region}}
kubectl get nodes
```

If this hangs or times out and `endpoint_public_access` is `false`, you need to be on the VPN/bastion that reaches the private subnets.

---

## Active alarms — what they mean

### Nodes not joining the cluster

New nodes stuck in `NotReady`, or the node group won't scale up.

```bash
# Node group status and any recent scaling activity/errors
aws eks describe-nodegroup \
  --cluster-name {{artifacts.cluster.cluster_name}} \
  --nodegroup-name {{slug}}-nodes \
  --query 'nodegroup.{status:status,health:health}'
```

Common causes: the node IAM role lost a policy attachment, the private subnets ran out of IPs, or the AMI release used by the node group was deprecated. Check `kubectl describe node <name>` for kubelet-side detail once a node does join.

### App stuck `Pending` — insufficient capacity

```bash
kubectl get pods -A --field-selector=status.phase=Pending
kubectl describe pod <pod> | tail -20   # look for "Insufficient cpu/memory" events
```

If it's capacity, bump `node_max_size` (and `node_desired_size` if you need it immediately — autoscaling only fires if a cluster autoscaler is installed) and redeploy.

### Ingress / ALB not provisioning

An app's `Ingress` resource never gets an address.

```bash
kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=100
kubectl describe ingress <app-ingress> -n <app-namespace>
```

Most common cause: the app's Ingress is missing the `kubernetes.io/ingress.class: alb` annotation (or `ingressClassName: alb`), or referencing a certificate ARN that doesn't exist / isn't `ISSUED` in ACM yet.

---

## Common operations

### Rolling a node group to pick up an AMI update

```bash
aws eks update-nodegroup-version \
  --cluster-name {{artifacts.cluster.cluster_name}} \
  --nodegroup-name {{slug}}-nodes
```

### Checking what's running where

```bash
kubectl get pods -A -o wide --sort-by=.spec.nodeName
```

### Verifying IRSA is actually working for an app

```bash
# Exec into any pod using a service account with an eks.amazonaws.com/role-arn
# annotation, and confirm STS hands back the scoped role, not the node role.
kubectl exec -it <pod> -n <namespace> -- aws sts get-caller-identity
```

If it returns the node IAM role instead of the app's scoped role, the service account annotation or the OIDC trust policy condition doesn't match — recheck `{{artifacts.cluster.oidc_provider_url}}` against what's in the role's trust policy.

---

## Disaster recovery

The control plane version (`{{params.cluster_version}}`) upgrades in place — plan a maintenance window and upgrade one minor version at a time, add-ons included. Losing the whole cluster means every app on it redeploys from scratch onto a new cluster instance; there's no fast "restore" path for compute, only for the stateful data services apps are connected to.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-eks-cluster/operator.md
