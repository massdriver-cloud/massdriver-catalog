---
templating: mustache
---

# Application — Operator Runbook

- **Instance:** `{{id}}`
- **Namespace:** `{{params.namespace}}`

## Connect kubectl

```bash
aws eks update-kubeconfig \
  --region {{#connections.eks}}{{connections.eks.region}}{{/connections.eks}} \
  --name {{#connections.eks}}{{connections.eks.name}}{{/connections.eks}}

kubectl get pods -n {{params.namespace}}
```

## Inspect the running workload

```bash
kubectl get deployment -n {{params.namespace}}
kubectl describe deployment -n {{params.namespace}} {{params.namespace}}
kubectl logs -n {{params.namespace}} -l app.kubernetes.io/instance={{params.namespace}} --tail=200
kubectl get events -n {{params.namespace}} --sort-by=.lastTimestamp | tail -20
```

## Verify connection wiring

The pod runs nginx (`public.ecr.aws/nginx/nginx:1.27`). Connection metadata is wired in as environment variables. Read them directly with `kubectl exec`:

```bash
POD=$(kubectl get pod -n {{params.namespace}} \
  -l app.kubernetes.io/instance={{params.namespace}} \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n {{params.namespace}} "$POD" -- env | grep -E '^(DB|S3|EKS)_'
```

Expected env keys, populated from connection data at deploy time:

- `DB_HOST`, `DB_READER_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_SECRET_ARN`
- `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`
- `EKS_CLUSTER_NAME`, `EKS_CLUSTER_REGION`

Database credentials are not in env vars. `DB_SECRET_ARN` (`{{#connections.database}}{{connections.database.secret_arn}}{{/connections.database}}`) points at AWS Secrets Manager. A real workload pulls credentials at runtime; this demo pod does not.

## Pods are not scheduling

Fargate-only clusters require the namespace to be matched by a Fargate profile. Verify:

```bash
aws eks list-fargate-profiles \
  --region {{#connections.eks}}{{connections.eks.region}}{{/connections.eks}} \
  --cluster-name {{#connections.eks}}{{connections.eks.name}}{{/connections.eks}}
```

If `{{params.namespace}}` is not covered by any profile, edit the cluster bundle's `fargate_namespaces` to include it and redeploy the cluster.

## Granting the workload access to AWS

This bundle is a wiring demo and does not bind IAM policies to the pod. The recommended pattern when forking the chart for a real workload is to run an IRSA-bound ServiceAccount and bind one of the connected bundle's `policies` array entries (the RDS bundle exposes Read / Write / Admin; the S3 bundle exposes Read / Write / Presign Upload / Admin) to the underlying IAM role.

This catalog's `aws-eks-fargate` bundle does not provision an OIDC provider, so IRSA needs to be set up out-of-band first. See the EKS bundle's operator runbook for the issuer URL.

If a workload is failing to reach the database or bucket, also check:

1. RDS security group `{{#connections.database}}{{connections.database.security_group_id}}{{/connections.database}}` allows ingress on TCP 5432 from the cluster's pod security group.
2. The pod's IAM identity (when configured) has `secretsmanager:GetSecretValue` on the secret ARN.
3. For SSE-KMS S3 buckets, the role also needs `kms:Decrypt` (and `kms:GenerateDataKey` for writers) on `{{#connections.bucket}}{{connections.bucket.kms_key_arn}}{{/connections.bucket}}`.

## Helm rollback

The chart is shipped inside this bundle and installed as Helm release `{{params.namespace}}` in namespace `{{params.namespace}}`.

```bash
helm status {{params.namespace}} -n {{params.namespace}}
helm history {{params.namespace}} -n {{params.namespace}}
helm rollback {{params.namespace}} <previous-revision> -n {{params.namespace}}
```

A Helm rollback is reverted on the next Massdriver deploy. Fix the underlying chart or params and redeploy through Massdriver to make the change permanent.

## Updating the chart

The chart is in `chart/` inside this bundle. Edit the chart, republish the bundle on the development release channel, and the instance redeploys with the new chart version.

## Known constraints

- `namespace` is immutable. Renaming requires destroying the package and redeploying.
- The pod is plain nginx — it will not pick up DB env-var changes on its own. Restarting the pod after a connection change reloads the env block.
