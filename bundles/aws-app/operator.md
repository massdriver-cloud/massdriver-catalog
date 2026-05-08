---
templating: mustache
---

# Application — Operator Runbook

- **Instance:** `{{id}}`
- **Namespace:** `{{params.namespace}}`

## Connect kubectl

```bash
aws eks update-kubeconfig \
  --region {{#connections.kubernetes_cluster}}{{connections.kubernetes_cluster.region}}{{/connections.kubernetes_cluster}} \
  --name {{#connections.kubernetes_cluster}}{{connections.kubernetes_cluster.name}}{{/connections.kubernetes_cluster}}

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

The workload runs the `mendhak/http-https-echo` image, which echoes its environment back on every request. Port-forward and curl to confirm the env vars derived from connections are present:

```bash
kubectl port-forward -n {{params.namespace}} svc/{{params.namespace}} 8080:80 &
curl -s localhost:8080 | jq .env
```

Expected env keys, populated from connection data at deploy time:

- `DB_HOST`, `DB_READER_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_SECRET_ARN`
- `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`, `S3_UPLOAD_PREFIX`
- `EKS_CLUSTER_NAME`, `EKS_CLUSTER_REGION`, `EKS_OIDC_PROVIDER_ARN`

Database credentials are NOT in env vars. The application fetches them at runtime from Secrets Manager using `DB_SECRET_ARN` (`{{#connections.database}}{{connections.database.secret_arn}}{{/connections.database}}`). This avoids stale credentials in pod env after a rotation.

## Pods are not scheduling

Fargate-only clusters require the namespace to be matched by a Fargate profile. Verify:

```bash
aws eks list-fargate-profiles \
  --region {{#connections.kubernetes_cluster}}{{connections.kubernetes_cluster.region}}{{/connections.kubernetes_cluster}} \
  --cluster-name {{#connections.kubernetes_cluster}}{{connections.kubernetes_cluster.name}}{{/connections.kubernetes_cluster}}
```

If `{{params.namespace}}` is not covered by any profile, edit the cluster bundle's `fargate_namespaces` to include it and redeploy the cluster.

## Application cannot connect to the database

1. The IAM role bound to the pod's ServiceAccount must hold the `{{params.database_policy}}` policy (one of Read / Write / Admin from the connected RDS bundle's `policies` array).
2. RDS security group `{{#connections.database}}{{connections.database.security_group_id}}{{/connections.database}}` must allow ingress on TCP 5432 from cluster security group `{{#connections.kubernetes_cluster}}{{connections.kubernetes_cluster.cluster_security_group_id}}{{/connections.kubernetes_cluster}}`.
3. Confirm the pod can read the secret:

```bash
kubectl exec -n {{params.namespace}} <pod-name> -- \
  aws secretsmanager get-secret-value \
  --region {{#connections.database}}{{connections.database.region}}{{/connections.database}} \
  --secret-id {{#connections.database}}{{connections.database.secret_arn}}{{/connections.database}}
```

If the call fails with `AccessDenied`, the IRSA role lacks `secretsmanager:GetSecretValue` on the secret ARN.

## Browser uploads to S3 are failing

1. The pod's IAM role must hold the `{{params.bucket_policy}}` policy (one of Read / Write / Presign Upload / Admin from the connected S3 bundle's `policies` array) — typically `Presign Upload` for browser-direct UGC.
2. The browser request must use the same `Content-Type` that was signed.
3. If the bucket uses SSE-KMS, the role also needs `kms:GenerateDataKey` on `{{#connections.bucket}}{{connections.bucket.kms_key_arn}}{{/connections.bucket}}`.

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
- Database credentials are pulled at runtime from Secrets Manager — they are not in the pod's env. Restarting the pod is sufficient to pick up a rotated password.
- The IRSA role is recreated when the package is renamed. Out-of-band IAM grants on the old role ARN must be reapplied.
