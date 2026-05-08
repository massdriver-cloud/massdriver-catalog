# Application Runbook

It's 2am. The app is down. Here's what to check.

## Pods aren't scheduling

Fargate-only clusters require the namespace to be in a Fargate profile. If the configured `namespace` isn't covered, pods sit in `Pending` forever. Check the cluster bundle's `fargate_profiles` list.

## App can't connect to the database

1. The IAM role bound to the pod's ServiceAccount needs the `database_policy` you selected.
2. The RDS security group must allow ingress from the cluster security group.
3. If `iam_auth_enabled` is on, the app must request a fresh IAM auth token per connection (15-minute TTL).

## Browser uploads to S3 are failing

The most common UGC issue: the IAM role can sign the URL, but the URL doesn't satisfy the bucket policy.

- Confirm the workload role has the `bucket_policy` you selected (typically `Presign Upload`).
- The browser request must use the same `Content-Type` that was signed.
- If the bucket uses SSE-KMS, the role also needs `kms:GenerateDataKey` on the bucket's KMS key.

## Updating the chart version

1. Bump `chart.version` and redeploy.
2. Helm will run `upgrade`. Watch the deploy log for failed hooks.
3. If anything looks off: `helm rollback <release> <previous-revision> -n <namespace>`.

## Scaling

Adjust `replicas` and redeploy. Fargate provisions per-pod capacity; expect 30–90s of pod cold-start under burst.

## Where to look first

- Application logs: `kubectl logs -n <namespace> -l app.kubernetes.io/name=<chart>`
- Helm release: `helm status <release> -n <namespace>`
- Pod events: `kubectl get events -n <namespace> --sort-by=.lastTimestamp`
