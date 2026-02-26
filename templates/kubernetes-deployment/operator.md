# {{ name }} Operator Runbook

This runbook provides operational guidance for the {{ name }} Kubernetes deployment.

## Overview

{{ description }}

## Common Operations

### Scaling

Update the `replicas` parameter and redeploy, or use kubectl:
```bash
kubectl scale deployment {{ name }} -n <namespace> --replicas=<count>
```

### Updating the Image

1. Update `image.repository` and/or `image.tag` parameters
2. Redeploy the bundle

### Viewing Logs

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name={{ name }} -f
```

### Restarting Pods

```bash
kubectl rollout restart deployment {{ name }} -n <namespace>
```

## Troubleshooting

### Deployment Failures

1. Check the deployment logs in Massdriver
2. Verify the container image exists and is accessible
3. Check Kubernetes events: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`

### Pod Issues

```bash
# Check pod status
kubectl get pods -n <namespace> -l app.kubernetes.io/name={{ name }}

# View pod logs
kubectl logs -n <namespace> -l app.kubernetes.io/name={{ name }}

# Describe pod for events
kubectl describe pods -n <namespace> -l app.kubernetes.io/name={{ name }}
```

### Resource Issues

If pods are being OOMKilled or throttled, increase the resource limits in the `resources` parameter.

## Support

For additional support, contact your platform team or visit the [Massdriver documentation](https://docs.massdriver.cloud).
