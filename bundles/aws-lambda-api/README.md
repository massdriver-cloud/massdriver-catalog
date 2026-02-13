# AWS Lambda API

Serverless REST API using AWS Lambda with API Gateway HTTP API. Includes PostgreSQL connectivity via the `pg` Node.js library.

## Features

- **API Gateway HTTP API** - Low-latency, cost-effective HTTP endpoints
- **VPC Integration** - Lambda runs in private subnets for secure database access
- **PostgreSQL Support** - Pre-bundled `pg` library for database connectivity
- **Auto-scaling** - Scales automatically with request volume
- **X-Ray Tracing** - Built-in distributed tracing

## Architecture

```
Internet → API Gateway HTTP API → Lambda (VPC) → RDS PostgreSQL
```

## Connections

| Name | Type | Description |
|------|------|-------------|
| `aws_authentication` | `aws-iam-role` | AWS credentials for deployment |
| `database` | `aws-rds-postgres` | PostgreSQL database connection |
| `vpc` | `aws-vpc` | VPC for Lambda to access private resources |

## Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `api_name` | string | `todo-api` | Name for your API |
| `memory_size` | integer | `256` | Lambda memory allocation (MB) |
| `timeout` | integer | `30` | Maximum execution time (seconds) |

## Outputs

- `api_url` - Public HTTPS endpoint for the API
- `function_name` - Lambda function name for CLI operations
- `function_arn` - Lambda ARN for IAM policies

## Changelog

### 0.0.2

- Switch to Node.js runtime with `pg` library
- Upload Lambda code to S3 instead of inline
- Add VPC integration for private database access
- Use `.checkov.yml` for security policy configuration
- Enable SSL for PostgreSQL connections (required by RDS)
