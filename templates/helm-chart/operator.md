# {{ name }} Operator Runbook

This runbook provides operational guidance for the {{ name }} Helm chart bundle.

## Overview

{{ description }}

This bundle deploys an external Helm chart from a remote repository.

## Configuration

The chart is configured via params:
- `chart.repository` - Helm chart repository URL
- `chart.name` - Chart name in the repository
- `chart.version` - Chart version (optional, defaults to latest)
- `namespace` - Target Kubernetes namespace

Override chart values by editing `chart/values.yaml` or adding a `chart/params.jq` file.

## Common Operations

### Upgrading the Chart Version

1. Update the `chart.version` parameter
2. Redeploy the bundle

### Viewing Release Status

```bash
helm status <release-name> -n <namespace>
helm history <release-name> -n <namespace>
```

### Rolling Back

```bash
helm rollback <release-name> <revision> -n <namespace>
```

## Troubleshooting

### Deployment Failures

1. Check the deployment logs in Massdriver
2. Verify the chart repository is accessible
3. Confirm the chart name and version exist
4. Check Kubernetes events: `kubectl get events -n <namespace>`

### Pod Issues

```bash
kubectl get pods -n <namespace>
kubectl logs -n <namespace> <pod-name>
kubectl describe pod -n <namespace> <pod-name>
```

## References

- [Helm Provisioner Docs](https://docs.massdriver.cloud/provisioners/helm)
- [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec)
