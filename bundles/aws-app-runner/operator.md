# AWS App Runner Bundle - Operator Runbook

## Bundle Overview

The `aws-app-runner` bundle creates a managed serverless container service with:
- Automatic scaling based on traffic
- Built-in load balancing and TLS
- Optional VPC connectivity for private resources
- Automatic database connection injection

## Prerequisites

### Connections Required

- **aws_authentication** (required): AWS IAM Role artifact (environment default)
- **vpc** (optional): aws-vpc artifact for VPC connectivity
- **database** (optional): postgres artifact for database connection

## Configuration Parameters

### region
- **Type**: string
- **Description**: AWS region for App Runner service
- **Default**: us-east-1

### container
- **image**: Container image URL (e.g., public.ecr.aws/repository/image:tag)
- **port**: Container port (default: 8080)
- **cpu**: vCPU allocation (0.25, 0.5, 1, 2, 4 vCPU)
- **memory**: Memory allocation (0.5 GB to 12 GB)
- **env**: Environment variables array

### scaling
- **min_instances**: Minimum running instances (1-25)
- **max_instances**: Maximum instances (1-25)
- **max_concurrency**: Max concurrent requests per instance (1-200)

### ingress
- **Type**: string
- **Options**: public, private
- **Default**: public

## Artifacts Produced

### service (application)

The bundle produces an `application` artifact containing:

```json
{
  "url": "https://xxxxx.us-east-1.awsapprunner.com",
  "arn": "arn:aws:apprunner:us-east-1:123456789:service/name/id"
}
```

## Database Connection

When connected to a postgres artifact, the following environment variables are automatically injected:

- `DATABASE_HOST` - Database hostname
- `DATABASE_PORT` - Database port
- `DATABASE_NAME` - Database name
- `DATABASE_USER` - Database username
- `DATABASE_PASSWORD` - Database password
- `DATABASE_URL` - Full connection string

## Deployment

### Initial Deployment

```bash
# Configure the package
mass pkg cfg <project>-<env>-<manifest> --params=/path/to/params.json

# Deploy
mass pkg deploy <project>-<env>-<manifest> -m "Initial App Runner deployment"
```

## Troubleshooting

### Service Not Starting

**Error**: Health check failures

**Solution**:
- Ensure container exposes the configured port
- Verify health check endpoint `/` returns 2xx
- Check container logs in App Runner console

### Cannot Connect to Database

**Error**: Database connection timeout

**Solution**:
- Ensure VPC artifact is connected
- The VPC connector enables private VPC access
- Database security group must allow traffic from VPC CIDR

### Image Pull Failures

**Error**: Cannot pull image

**Solution**:
- For ECR Private: Ensure access role has ECR permissions
- For public images: Use `ECR_PUBLIC` repository type
- Verify image URL is correct

## Resources Created

- 1 App Runner Service
- 1 Auto Scaling Configuration
- 1 IAM Instance Role
- 1 IAM Access Role
- 1 VPC Connector (if VPC connected)
- 1 Security Group (if VPC connected)

## Cost Considerations

Estimated monthly costs (us-east-1):
- **Compute**: $0.064/vCPU-hour + $0.007/GB-hour
- **Provisioned Concurrency**: $5/month per provisioned instance
- **Requests**: Free (included in compute)

**Example (1 vCPU, 2GB, 1 instance minimum)**:
- ~$50/month base
- Scales with traffic automatically
