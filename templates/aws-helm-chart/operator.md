# {{ name }} Runbook

## Pods aren't scheduling

If you're targeting an EKS Fargate cluster, the namespace must be covered by a Fargate profile. Check the cluster's `fargate_namespaces` param — add the namespace and redeploy the cluster bundle.

## Helm release is stuck

```bash
helm status {{ name }} -n <namespace>
helm history {{ name }} -n <namespace>
```

If a release is stuck `pending-upgrade`, a hook usually failed mid-upgrade. Roll back: `helm rollback {{ name }} <previous-revision> -n <namespace>`.

## Workload can't reach AWS data resources

For each connected AWS resource (database, bucket, etc.), the workload's IAM role must hold a matching policy. The policies live on the connected resource's artifact under `policies` — bind one to your workload's ServiceAccount via IRSA.

This catalog's `aws-eks-fargate` bundle does not provision an OIDC provider. If the workload needs IRSA, register the cluster's OIDC issuer as an IAM identity provider out-of-band, then annotate the ServiceAccount with `eks.amazonaws.com/role-arn`.

## Useful commands

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name={{ name }}
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```
