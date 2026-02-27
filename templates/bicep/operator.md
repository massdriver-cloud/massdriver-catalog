# {{ name }} Operator Runbook

This runbook provides operational guidance for the {{ name }} bundle.

## Overview

{{ description }}

## Common Operations

### Scaling

To adjust the number of instances, update the `instance_count` parameter and redeploy.

### Monitoring

When `enable_monitoring` is enabled, Azure Monitor metrics are collected.

## Troubleshooting

### Deployment Failures

1. Check the deployment logs in Massdriver
2. Verify the Azure Service Principal has required permissions
3. Ensure parameter values meet validation requirements
4. Check Azure resource quotas in the target region

### Performance Issues

1. Review current instance count and consider scaling up
2. Check Azure Monitor metrics for resource utilization

## Support

For additional support, contact your platform team or visit the [Massdriver documentation](https://docs.massdriver.cloud).
