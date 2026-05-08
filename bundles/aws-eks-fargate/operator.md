# AWS EKS Fargate Runbook

It's 2am. Pods aren't running. Here's what to check.

## Pods stuck in `Pending`

The most common Fargate failure mode: the pod's namespace isn't covered by a Fargate profile.

1. Get the namespace: `kubectl get pod <pod> -o jsonpath='{.metadata.namespace}'`
2. List Fargate profiles: `aws eks list-fargate-profiles --cluster-name <cluster>`
3. If the namespace isn't in `fargate_namespaces`, add it and redeploy. Existing pods will not migrate automatically — delete them once the profile exists.

## CoreDNS is `Pending`

CoreDNS runs in `kube-system`. If you removed `kube-system` from `fargate_namespaces`, CoreDNS has nowhere to schedule and the whole cluster's DNS resolution breaks. Add `kube-system` back.

## Cannot reach the API server

If `endpoint_access` is `private-only`, you can only reach the API from inside the VPC. Use a bastion, VPN, or AWS SSM port-forward. The `aws eks update-kubeconfig` command works regardless of access mode — what fails is the actual API call.

## Audit logs missing

Check `log_types` includes `audit`. CloudWatch log group is `/aws/eks/<cluster_name>/cluster`.

## Pod IAM permissions

Pods authenticate to AWS via IRSA (IAM Roles for Service Accounts). Bind the workload's ServiceAccount to an IAM role whose trust policy references this cluster's OIDC provider — it's exposed in the cluster artifact under `oidc.provider_arn`.
