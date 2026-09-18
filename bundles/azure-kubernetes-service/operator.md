---
templating: mustache
---

# Kubernetes Runbook

## Get access

{{#resources.cluster}}
```bash
az aks get-credentials --name {{resources.cluster.name}} --resource-group {{resources.cluster.name}}
kubectl get nodes -o wide
```
{{/resources.cluster}}

## A pod stays in `Pending`

The subnet holds no free address, or the scaler reached the maximum node count.

1. Read the reason.
   ```bash
   kubectl describe pod <POD> | sed -n '/Events/,$p'
   ```
2. Read the node count against the maximum of {{params.max_nodes}}.
   ```bash
   kubectl get nodes --no-headers | wc -l
   ```
3. Raise the maximum in the form, or give the network a larger subnet. The Azure
   network plugin takes about 30 addresses per node, so a /24 subnet holds about
   8 nodes.

## An upgrade fails

Azure upgrades one minor version at a time.

{{#resources.cluster}}
```bash
az aks get-upgrades --name {{resources.cluster.name}} --resource-group {{resources.cluster.name}} --output table
```
{{/resources.cluster}}

Set the next version in the form, deploy, then repeat until you reach the target.

## A node is not ready

```bash
kubectl get nodes | grep -v " Ready"
kubectl describe node <NODE> | sed -n '/Conditions/,/Addresses/p'
```

Cordon and drain the node, then delete it. The scaler builds a replacement.

```bash
kubectl drain <NODE> --ignore-daemonsets --delete-emptydir-data
kubectl delete node <NODE>
```

## Nobody can reach the API server

The cluster carries a private API server, and it answers inside the network
only. Reach it from a workload inside the network, or open a private link.

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
