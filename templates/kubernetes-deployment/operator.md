# {{ name }} Operator Runbook

This runbook provides operational guidance for the {{ name }} Kubernetes deployment.

## Overview

{{ description }}

This bundle deploys a containerized application to Kubernetes using Helm.

## Configuration

Key params:
- `image.repository` / `image.tag` - Container image
- `namespace` - Target Kubernetes namespace
- `replicas` - Number of pod replicas
- `port` - Container port
- `resources` - CPU/memory requests and limits
- `env` - Environment variables

## Common Operations

### Scaling

Update the `replicas` parameter and redeploy, or use kubectl:
```bash
kubectl scale deployment <release-name> -n <namespace> --replicas=<count>
```

### Updating the Image

1. Update `image.repository` and/or `image.tag` parameters
2. Redeploy the bundle

### Viewing Logs

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=<release-name> -f
```

### Restarting Pods

```bash
kubectl rollout restart deployment <release-name> -n <namespace>
```

### Viewing Release Status

```bash
helm status <release-name> -n <namespace>
helm history <release-name> -n <namespace>
```

## Troubleshooting

### Deployment Failures

1. Check the deployment logs in Massdriver
2. Verify the container image exists and is accessible
3. Check Kubernetes events: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`

### Pod Issues

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<release-name>
kubectl describe pods -n <namespace> -l app.kubernetes.io/name=<release-name>
```

### Resource Issues

If pods are being OOMKilled or CPU throttled, increase the resource limits.

## References

- [Helm Provisioner Docs](https://docs.massdriver.cloud/provisioners/helm)
- [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec)
