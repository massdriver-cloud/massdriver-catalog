# AWS App Runner Operations Guide

## Overview

This bundle provisions an AWS App Runner service for running containerized applications with automatic scaling, load balancing, and optional VPC connectivity.

## Resources Created

| Resource | Purpose |
|----------|---------|
| App Runner Service | Managed container hosting |
| Auto Scaling Config | Min/max instance scaling |
| IAM Access Role | ECR image pull permissions |
| IAM Instance Role | Runtime permissions |
| VPC Connector | Private VPC access (optional) |
| Security Group | VPC connector egress rules (optional) |

## Configuration

### Service URL
**{{artifact "service" "data.url"}}**

### Container Settings
- **Image:** {{params.container.image}}
- **Port:** {{params.container.port}}
- **CPU:** {{params.container.cpu}} (millicores)
- **Memory:** {{params.container.memory}} MB

### Scaling
- **Min Instances:** {{params.scaling.min_instances}}
- **Max Instances:** {{params.scaling.max_instances}}
- **Max Concurrency:** {{params.scaling.max_concurrency}} requests/instance

## Troubleshooting

### Service won't start
1. Check container image exists and is accessible
2. Verify port matches what container listens on
3. Review App Runner logs in CloudWatch
4. Ensure health check path returns 200

### Can't connect to database
1. Verify VPC connector is configured
2. Check security group allows egress to database port
3. Ensure database security group allows App Runner CIDR
4. Verify DATABASE_* environment variables are set

### Slow cold starts
1. Increase min_instances to keep instances warm
2. Optimize container startup time
3. Consider smaller container images

### 502/503 errors
1. Check health check configuration matches your app
2. Review application logs for crashes
3. Verify memory allocation is sufficient
4. Check for OOM kills in CloudWatch metrics

## Monitoring

### CloudWatch Metrics
Key metrics to monitor:
- `RequestCount` - Total requests
- `RequestLatency` - Response time (p50, p90, p99)
- `ActiveInstances` - Running instance count
- `2xxStatusResponses` / `4xxStatusResponses` / `5xxStatusResponses`

### Application Logs
View in CloudWatch Logs:
```
/aws/apprunner/{{artifact "service" "data.id"}}/service
```

### Health Checks
- Protocol: HTTP
- Path: /
- Interval: 10 seconds
- Healthy threshold: 1
- Unhealthy threshold: 5

## Database Integration

When connected to a PostgreSQL database, these environment variables are automatically injected:

| Variable | Description |
|----------|-------------|
| `DATABASE_HOST` | Database hostname |
| `DATABASE_PORT` | Database port (5432) |
| `DATABASE_NAME` | Database name |
| `DATABASE_USER` | Database username |
| `DATABASE_PASSWORD` | Database password |
| `DATABASE_URL` | Full connection string |

## Scaling Considerations

- **Horizontal:** Auto-scales based on concurrent requests
- **Max concurrency:** Requests per instance before scaling out
- **Min instances:** Keep > 0 to avoid cold starts
- **Max instances:** Hard limit on scaling (cost control)

## Deployment

App Runner automatically deploys when:
- Manual deployment triggered via console/CLI
- Source repository changes (if connected)
- Configuration changes via Massdriver

## Related Bundles

This service is typically used with:
- `aws-vpc` - VPC for private resource access
- `aws-aurora-postgres` - PostgreSQL database
