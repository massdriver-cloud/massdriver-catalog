# Kubernetes Runbook

{{#resources.cluster}}
| Field | Value |
|---|---|
| Cluster | `{{resources.cluster.data.name}}` |
| Version | `{{resources.cluster.data.version}}` |
| Region | `{{resources.cluster.data.region}}` |
{{/resources.cluster}}

## A pod stays in `Pending`

**Diagnosis.** The subnet has no free address, or the scaler reached the maximum
node count.

**Fix.** Check the events, then raise the maximum, or give the network a larger
subnet.

```bash
kubectl get events --sort-by=.lastTimestamp | tail -20
```

## An upgrade fails

**Diagnosis.** Azure upgrades one minor version at a time.

**Fix.** Upgrade to the next version, deploy, then repeat.

```bash
az aks get-upgrades --name <CLUSTER> --resource-group <GROUP> --output table
```

## Nobody can reach the API server

**Diagnosis.** The cluster has a private API server. It answers inside the
network only.

**Fix.** Reach it from a workload inside the network, or open a private link.

## Warning: the subnet fills up

The Azure network plugin gives every pod an address from the subnet. A `/24`
subnet holds about 8 nodes. Plan the range before the cluster grows.

## Get a kubeconfig

```bash
az aks get-credentials --name <CLUSTER> --resource-group <GROUP>
```
