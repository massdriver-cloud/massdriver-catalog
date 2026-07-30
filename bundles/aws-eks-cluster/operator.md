---
templating: mustache
---

# AWS Kubernetes Cluster Runbook

## Getting kubectl access

```bash
aws eks update-kubeconfig \
  --name {{artifacts.cluster.cluster_name}} \
  --region {{artifacts.cluster.region}}
kubectl get nodes
```

If this times out and `endpoint_public_access` is `false`, connect through the VPN or bastion that reaches the private subnets.

## Alarms

### Nodes not joining the cluster

New nodes stuck in `NotReady`, or the node group will not scale up.

```bash
# Node group status and any recent scaling activity/errors
aws eks describe-nodegroup \
  --cluster-name {{artifacts.cluster.cluster_name}} \
  --nodegroup-name {{slug}}-nodes \
  --query 'nodegroup.{status:status,health:health}'
```

Common causes: the node IAM role lost a policy attachment, the private subnets ran out of IPs, or the node group's AMI release was deprecated. Once a node does join, check `kubectl describe node <name>` for kubelet-side detail.

### Pods stuck Pending on insufficient capacity

```bash
kubectl get pods -A --field-selector=status.phase=Pending
kubectl describe pod <pod> | tail -20   # look for "Insufficient cpu/memory" events
```

If it is capacity, raise `node_max_size` (and `node_desired_size` if capacity is needed immediately; autoscaling only fires if a cluster autoscaler is installed) and redeploy.

### Ingress load balancer not provisioning

An app's `Ingress` resource never gets an address.

```bash
kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=100
kubectl describe ingress <app-ingress> -n <app-namespace>
```

Most common causes: the Ingress is missing the `kubernetes.io/ingress.class: alb` annotation (or `ingressClassName: alb`), or it references a certificate ARN that does not exist or is not `ISSUED` in ACM.

## Common operations

### Roll the node group to pick up an AMI update

```bash
aws eks update-nodegroup-version \
  --cluster-name {{artifacts.cluster.cluster_name}} \
  --nodegroup-name {{slug}}-nodes
```

### Check what is running where

```bash
kubectl get pods -A -o wide --sort-by=.spec.nodeName
```

### Verify IRSA for an app

```bash
# Exec into any pod using a service account with an eks.amazonaws.com/role-arn
# annotation, and confirm STS hands back the scoped role, not the node role.
kubectl exec -it <pod> -n <namespace> -- aws sts get-caller-identity
```

If it returns the node IAM role instead of the app's scoped role, the service account annotation or the OIDC trust policy condition does not match. Compare `{{artifacts.cluster.oidc_provider_url}}` against the role's trust policy.

## Disaster recovery

The control plane version upgrades in place. Plan a maintenance window and upgrade one minor version at a time, add-ons included. Losing the whole cluster means redeploying every app onto a new cluster instance; there is no restore path for compute, only for the stateful data services apps connect to.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-eks-cluster/operator.md
