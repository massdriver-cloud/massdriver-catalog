# TODO API - Lambda Demo App

A minimal Node.js REST API for AWS Lambda + API Gateway + DynamoDB.

## Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | /todos | List all todos |
| GET | /todos/{id} | Get a todo |
| POST | /todos | Create a todo |
| PUT | /todos/{id} | Update a todo |
| DELETE | /todos/{id} | Delete a todo |

### Request/Response Examples

**Create:**
```bash
curl -X POST https://your-api/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy milk"}'
# => {"pk":"uuid","title":"Buy milk","completed":false,"createdAt":"..."}
```

**Update:**
```bash
curl -X PUT https://your-api/todos/{id} \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
```

## DynamoDB Table

Create a table with:

| Setting | Value |
|---------|-------|
| **Partition key** | `pk` (String) |
| **Billing mode** | On-demand (PAY_PER_REQUEST) recommended |

No sort key needed. No GSIs needed. That's it.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DYNAMODB_TABLE` | Name of the DynamoDB table |

## IAM Policy

The Lambda execution role needs DynamoDB access to the table. Minimum actions:

```
dynamodb:PutItem
dynamodb:GetItem
dynamodb:DeleteItem
dynamodb:Scan
```

## Packaging for S3

```bash
npm install
npm run package
# Upload todoapi.zip to your S3 bucket
```

Lambda config:
- **Runtime:** Node.js 20.x
- **Handler:** `index.handler`
- **Architecture:** arm64 or x86_64 (either works)
