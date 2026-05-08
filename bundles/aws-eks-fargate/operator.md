---
templating: mustache
---

# AWS EKS Fargate — Operator Runbook

- **Instance:** `{{id}}`
- **Cluster name:** `{{params.cluster_name}}`
- **API endpoint:** {{#artifacts.kubernetes_cluster}}`{{artifacts.kubernetes_cluster.endpoint}}`{{/artifacts.kubernetes_cluster}}

## Connect kubectl

```bash
aws eks update-kubeconfig \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --name {{params.cluster_name}}

kubectl get nodes
kubectl get pods -A
kubectl get fargateprofiles -A
```

## Inspect Fargate profiles

```bash
aws eks list-fargate-profiles \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --cluster-name {{params.cluster_name}}

aws eks describe-fargate-profile \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --cluster-name {{params.cluster_name}} \
  --fargate-profile-name <profile-name>
```

## Pods stuck in Pending

On a Fargate-only cluster, a pod's namespace must be matched by a Fargate profile or it has nowhere to schedule.

```bash
kubectl get pod <pod> -o jsonpath='{.metadata.namespace}'
kubectl describe pod <pod> -n <namespace>
```

If the namespace is not in the cluster's `fargate_namespaces` param, add it and redeploy. Existing Pending pods do not migrate automatically — delete them after the profile is created.

## Cluster DNS

The bundle does not manage CoreDNS. The cluster ships with whatever EKS provisions by default. If workloads need cluster DNS for service-to-service resolution and the default install is not running, configuring CoreDNS for Fargate is your responsibility — out of scope for this bundle.

Image pulls do not depend on CoreDNS; they resolve through VPC DNS.

## API server unreachable

The cluster API endpoint is configured for both public and private access. From inside the VPC, `kubectl` should reach the private endpoint directly. From outside the VPC, the public endpoint is reachable from any IP — there is no IP allowlist on this bundle. If the API call fails, confirm the kubeconfig context and that the calling identity is authorized:

```bash
aws eks describe-cluster \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --name {{params.cluster_name}} \
  --query 'cluster.{Endpoint:endpoint,Status:status,Version:version}'
```

## Workload IAM

This bundle does not provision an OIDC provider, so IRSA is not available out of the box. If a workload needs to call AWS APIs, either:

1. Bring up the OIDC provider out-of-band — fetch the cluster's issuer URL and register it as an `aws_iam_openid_connect_provider` in IAM, then annotate the ServiceAccount with `eks.amazonaws.com/role-arn`. Or,
2. Run with EC2 instance-profile credentials (not applicable on Fargate), or attach a node-level IAM identity at the pod-execution role (broad, not workload-scoped).

```bash
aws eks describe-cluster \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --name {{params.cluster_name}} \
  --query 'cluster.identity.oidc.issuer'
```

## The `massdriver` ServiceAccount

The bundle creates a `massdriver` ServiceAccount in `kube-system`, a `cluster-admin` ClusterRoleBinding, and a long-lived `kubernetes.io/service-account-token` Secret. The token is exposed on the artifact's `token` field and is consumed by the Massdriver helm provisioner to install Helm releases against this cluster. EKS only issues short-lived tokens via `aws eks get-token` (~15 minutes); a token Secret bound to a ServiceAccount is what the helm provisioner uses to authenticate without refreshing.

```bash
kubectl get serviceaccount massdriver -n kube-system
kubectl get secret massdriver-token -n kube-system
```

## Known constraints

- Fargate pods have a 15-minute startup budget. Image pulls beyond that fail the pod.
- Daemonsets are not supported on Fargate. Sidecar workloads (e.g., log shippers) must be added to each pod spec.
- Persistent volumes other than EFS are not supported on Fargate.
- A namespace can be matched by exactly one Fargate profile. Removing a namespace from `fargate_namespaces` does not evict running pods — they continue until pod restart.
