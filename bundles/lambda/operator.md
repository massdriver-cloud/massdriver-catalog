# Lambda TODO REST API

## Overview

This bundle deploys an AWS Lambda function with a public Function URL that provides a REST API for managing TODO items. The Lambda function integrates with DynamoDB for data persistence.

## Features

- **REST API Endpoints**: Complete CRUD operations for TODOs
- **Lambda Function URL**: Public HTTPS endpoint (no API Gateway needed)
- **DynamoDB Integration**: Configurable access levels (read-only, read-write, admin)
- **CORS Support**: Enabled for browser-based clients
- **CloudWatch Logging**: Automatic log retention configuration
- **X-Ray Tracing**: Enabled for observability

## API Endpoints

### List TODOs
```bash
GET {function_url}/todos
```

### Get TODO by ID
```bash
GET {function_url}/todos/{id}
```

### Create TODO
```bash
POST {function_url}/todos
Content-Type: application/json

{
  "title": "Buy groceries",
  "description": "Milk, eggs, bread"
}
```

### Update TODO
```bash
PUT {function_url}/todos/{id}
Content-Type: application/json

{
  "title": "Updated title",
  "completed": true
}
```

### Delete TODO
```bash
DELETE {function_url}/todos/{id}
```

## Configuration

### Lambda Settings
- **Memory**: 128MB - 3GB (affects performance and cost)
- **Timeout**: 3-900 seconds (30s recommended for API calls)

### DynamoDB Access Levels
- **read-only**: Lambda can only read TODOs (GET operations)
- **read-write**: Lambda can read and modify TODOs (all CRUD operations)
- **admin**: Full DynamoDB table access

### Log Retention
- **1-90 days**: Balance between cost and audit requirements
- **Recommendation**: 7 days for dev, 30+ days for production

## Testing

After deployment, test the API with curl:

```bash
# Set your function URL
FUNCTION_URL="<your-function-url-from-outputs>"

# Create a TODO
curl -X POST $FUNCTION_URL/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Test TODO", "description": "This is a test"}'

# List all TODOs
curl $FUNCTION_URL/todos

# Get specific TODO
curl $FUNCTION_URL/todos/{id}

# Update TODO
curl -X PUT $FUNCTION_URL/todos/{id} \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'

# Delete TODO
curl -X DELETE $FUNCTION_URL/todos/{id}
```

## Monitoring

CloudWatch Log Groups:
- `/aws/lambda/{function-name}` - Lambda execution logs
- `/aws/lambda-url/{function-name}` - Function URL access logs

## Security Considerations

- Function URL is **public** - no authentication required
- For production use, consider:
  - Adding API Gateway with authentication
  - Implementing IAM authorization
  - Adding WAF protection
  - Rate limiting

## Cost Optimization

- Use **read-only** policy if only displaying TODOs
- Adjust memory based on actual usage patterns
- Monitor CloudWatch metrics for optimization opportunities
