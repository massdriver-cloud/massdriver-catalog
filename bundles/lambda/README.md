# Lambda TODO REST API

AWS Lambda function with Function URL providing a complete REST API for managing TODO items, integrated with DynamoDB.

## Features

- Complete CRUD operations for TODO items
- Public Function URL (no API Gateway needed)
- Configurable DynamoDB access levels (read-only, read-write, admin)
- CORS support for browser clients
- CloudWatch logging with configurable retention
- X-Ray tracing enabled

## Architecture

```
┌─────────────┐     HTTP      ┌──────────────┐     boto3     ┌──────────────┐
│   Client    │──────────────▶│    Lambda    │──────────────▶│   DynamoDB   │
│  (Browser/  │   Function    │   Function   │   SDK calls   │    Table     │
│   API)      │     URL       │  (Python)    │               │              │
└─────────────┘               └──────────────┘               └──────────────┘
                                     │
                                     ▼
                              ┌──────────────┐
                              │  CloudWatch  │
                              │     Logs     │
                              └──────────────┘
```

## Usage

### Prerequisites

This bundle requires:
1. AWS IAM Role authentication (connection)
2. DynamoDB table (connection from dynamodb bundle)

### Deployment

1. Connect AWS authentication
2. Connect DynamoDB table output
3. Configure Lambda settings:
   - Memory allocation (512MB-1GB recommended)
   - Timeout (30-60 seconds)
   - DynamoDB access level
   - Log retention period

### Testing the API

After deployment, use the Function URL from outputs:

```bash
FUNCTION_URL="<your-function-url>"

# Create a TODO
curl -X POST $FUNCTION_URL/todos \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Buy groceries",
    "description": "Milk, eggs, bread"
  }'

# List all TODOs
curl $FUNCTION_URL/todos

# Get specific TODO
curl $FUNCTION_URL/todos/{id}

# Update TODO
curl -X PUT $FUNCTION_URL/todos/{id} \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Buy groceries (updated)",
    "completed": true
  }'

# Delete TODO
curl -X DELETE $FUNCTION_URL/todos/{id}
```

## API Response Format

### TODO Object
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Buy groceries",
  "description": "Milk, eggs, bread",
  "completed": false,
  "created_at": "2024-03-17T10:30:00Z",
  "updated_at": "2024-03-17T10:30:00Z"
}
```

### List Response
```json
{
  "todos": [...],
  "count": 5
}
```

### Error Response
```json
{
  "error": "TODO not found"
}
```

## DynamoDB Access Levels

- **read-only**: GET operations only (list, get by ID)
- **read-write**: Full CRUD operations (recommended for API)
- **admin**: Complete DynamoDB table access

## Monitoring

CloudWatch Log Groups:
- `/aws/lambda/{function-name}` - Lambda execution logs
- `/aws/lambda-url/{function-name}` - Function URL access logs

## Security Considerations

⚠️ **Important**: The Function URL is public with no authentication.

For production use, consider:
- Adding API Gateway with IAM/Cognito authentication
- Implementing request signing
- Adding AWS WAF for protection
- Setting up rate limiting
- Using VPC endpoints for DynamoDB access

## Cost Optimization

- Start with 512MB memory, adjust based on CloudWatch metrics
- Use **read-only** access if you only need GET operations
- Set appropriate log retention (7 days for dev, 30 days for prod)
- Monitor Lambda duration and throttles

## Troubleshooting

### 500 Internal Server Error
Check CloudWatch logs for detailed error messages:
```bash
aws logs tail /aws/lambda/{function-name} --follow
```

### DynamoDB Access Denied
Verify the DynamoDB access level is set correctly:
- read-only: Cannot perform PUT/POST/DELETE
- read-write: Can perform all CRUD operations

### CORS Errors
The Lambda function includes CORS headers. If you still see errors:
- Verify the request includes proper Content-Type header
- Check browser console for specific CORS error details

## Development

### Local Testing
The Lambda code is in `src/lambda_code/index.py`. To test locally:

```python
# Create a test event
event = {
    "requestContext": {
        "http": {
            "method": "GET"
        }
    },
    "rawPath": "/todos"
}

# Run the handler
from index import lambda_handler
result = lambda_handler(event, None)
print(result)
```

## Configuration

### Presets

**Development**
- 512MB memory
- 30 second timeout
- 7 day log retention
- read-write access

**Production**
- 1024MB memory
- 60 second timeout
- 30 day log retention
- read-write access
