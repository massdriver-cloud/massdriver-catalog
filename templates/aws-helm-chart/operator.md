# {{ name }} Runbook

It's 2am. The app is down. Here's what to check.

## Pods aren't scheduling

If you're targeting an EKS Fargate cluster, the namespace must be covered by a Fargate profile. Check the cluster's `fargate_profiles` list — add the namespace and redeploy.

## Helm release is stuck

```bash
helm status {{ name }} -n <namespace>
helm history {{ name }} -n <namespace>
```

If a release is stuck `pending-upgrade`, it usually means a hook failed mid-upgrade. Roll back: `helm rollback {{ name }} <previous-revision> -n <namespace>`.

## Workload can't reach AWS data resources

For each connected AWS resource (database, bucket, etc.), the workload's IAM role must hold a matching policy. The policies live on the data resource's artifact under `policies` — bind one to your workload's ServiceAccount via IRSA.

## Useful commands

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name={{ name }}
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```
