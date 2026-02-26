# {{ name }} Operator Runbook

This runbook provides operational guidance for the {{ name }} Helm chart bundle.

## Overview

{{ description }}

This bundle deploys an external Helm chart to a Kubernetes cluster.

## Common Operations

### Upgrading the Chart Version

1. Update the `helm.version` parameter to the desired version
2. Redeploy the bundle

### Scaling

Update the `replicas` parameter and redeploy.

### Custom Configuration

Use the `values` parameter to pass additional configuration to the Helm chart. This follows standard Helm values.yaml structure.

## Troubleshooting

### Deployment Failures

1. Check the deployment logs in Massdriver
2. Verify the Helm repository URL is accessible
3. Confirm the chart name and version exist in the repository
4. Check Kubernetes events: `kubectl get events -n <namespace>`

### Pod Issues

```bash
# Check pod status
kubectl get pods -n <namespace>

# View pod logs
kubectl logs -n <namespace> <pod-name>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>
```

## Support

For additional support, contact your platform team or visit the [Massdriver documentation](https://docs.massdriver.cloud).
