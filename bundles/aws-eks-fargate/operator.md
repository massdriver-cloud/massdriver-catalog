---
templating: mustache
---

# AWS EKS Fargate — Operator Runbook

- **Instance:** `{{id}}`
- **API endpoint:** {{#artifacts.cluster}}`{{artifacts.cluster.endpoint}}`{{/artifacts.cluster}}

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

## CoreDNS is Pending

CoreDNS runs in `kube-system`. If `kube-system` is not covered by `fargate_namespaces`, CoreDNS cannot schedule and cluster DNS resolution breaks. Add `kube-system` back and redeploy.

## API server unreachable

If `endpoint_access` is `private-only` (currently `{{params.endpoint_access}}`), the API is only reachable from inside the VPC. Use a bastion, VPN, Direct Connect, or AWS SSM port-forward. `aws eks update-kubeconfig` succeeds in any mode — what fails is the actual API call.

```bash
aws eks describe-cluster \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --name {{params.cluster_name}} \
  --query 'cluster.resourcesVpcConfig.{PublicAccess:endpointPublicAccess,PrivateAccess:endpointPrivateAccess,PublicCidrs:publicAccessCidrs}'
```

## Audit and control-plane logs

Logs are delivered to CloudWatch under `/aws/eks/{{params.cluster_name}}/cluster` for whichever log types the bundle's `log_types` param has enabled.

```bash
aws logs tail /aws/eks/{{params.cluster_name}}/cluster \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --follow

# Audit events only
aws logs tail /aws/eks/{{params.cluster_name}}/cluster \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --log-stream-name-prefix kube-apiserver-audit \
  --since 1h
```

## Workload IAM via IRSA

Workloads receive AWS credentials by binding a Kubernetes ServiceAccount to an IAM role through the cluster's OIDC provider.

The IAM role's trust policy must federate with {{#artifacts.cluster}}`{{artifacts.cluster.oidc.provider_arn}}`{{/artifacts.cluster}} and condition on the `system:serviceaccount:<namespace>:<sa-name>` subject.

```bash
kubectl annotate serviceaccount -n <namespace> <sa-name> \
  eks.amazonaws.com/role-arn=arn:aws:iam::{{#connections.vpc}}{{connections.vpc.account_id}}{{/connections.vpc}}:role/<role-name>

kubectl rollout restart deployment -n <namespace> <deployment-name>
```

Pods must be restarted after the annotation is added so the projected token is mounted.

## Known constraints

- Fargate pods have a 15-minute startup budget. Image pulls beyond that fail the pod.
- Daemonsets are not supported on Fargate. Sidecar workloads (e.g., log shippers) must be added to each pod spec.
- Persistent volumes other than EFS are not supported on Fargate.
- A namespace can be matched by exactly one Fargate profile. Removing a namespace from `fargate_namespaces` does not evict running pods — they continue until pod restart.
