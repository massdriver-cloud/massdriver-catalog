# AWS App Runner

AWS App Runner is a fully managed service that makes it easy to deploy containerized web applications and APIs at scale. This bundle provides a simplified deployment of App Runner for demo workloads.

## Features

- Fully managed container hosting
- Auto-scaling based on traffic
- Optional VPC integration for private resources
- Database credential injection
- Public or private ingress

## Use Cases

- Web applications
- REST APIs
- Microservices
- Demo and development environments

## Configuration

### Container

- **Image**: Full container image URL (supports ECR Public)
- **Port**: Container listening port (default: 8080)
- **CPU**: vCPU allocation (0.25 to 4 vCPU)
- **Memory**: Memory allocation (0.5 GB to 12 GB)
- **Environment Variables**: Custom environment variables

### Scaling

- **Min Instances**: Minimum running instances (1-25)
- **Max Instances**: Maximum instances for scaling (1-25)
- **Max Concurrency**: Concurrent requests per instance (1-200)

### Networking

- **Ingress**: Public or private access
- **VPC**: Optional VPC connection for private resource access
- **Database**: Optional PostgreSQL connection with auto-injected credentials

## Connections

### Required

- **AWS Authentication**: IAM role for AWS access

### Optional

- **VPC**: AWS VPC for private network access
- **Database**: PostgreSQL database (credentials auto-injected as env vars)

## Artifacts

- **Service**: Application artifact with service URL and metadata

## Database Environment Variables

When a database connection is provided, the following environment variables are automatically injected:

- `DATABASE_HOST`
- `DATABASE_PORT`
- `DATABASE_NAME`
- `DATABASE_USER`
- `DATABASE_PASSWORD`
- `DATABASE_URL` (full connection string)

## Notes

- App Runner does not support scale-to-zero (minimum 1 instance)
- VPC egress is only available when VPC connection is configured
- Public ECR images are supported by default
- For private ECR, additional IAM permissions are required
