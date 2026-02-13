---
templating: mustache
---

# Lambda TODO API - Operator Guide

## API Endpoint

Your API is live at:

```
{{artifacts.application.url}}
```

---

## Quick Start

### List all TODOs

```bash
curl {{artifacts.application.url}}todos
```

### Create a TODO

```bash
curl -X POST {{artifacts.application.url}}todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy groceries"}'
```

### Get a specific TODO

```bash
curl {{artifacts.application.url}}todos/1
```

### Update a TODO

```bash
curl -X PUT {{artifacts.application.url}}todos/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy organic groceries", "completed": true}'
```

### Delete a TODO

```bash
curl -X DELETE {{artifacts.application.url}}todos/1
```

---

## API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API info and available endpoints |
| GET | `/todos` | List all TODOs |
| GET | `/todos/{id}` | Get a specific TODO |
| POST | `/todos` | Create a new TODO |
| PUT | `/todos/{id}` | Update a TODO |
| DELETE | `/todos/{id}` | Delete a TODO |

### Request/Response Examples

**Create TODO Request:**
```json
{
  "title": "My new task"
}
```

**TODO Response:**
```json
{
  "id": 1,
  "title": "My new task",
  "completed": false
}
```

**List Response:**
```json
{
  "todos": [
    {"id": 1, "title": "Task 1", "completed": false},
    {"id": 2, "title": "Task 2", "completed": true}
  ]
}
```

---

## Database Connection

{{#connections.database}}
**Database is connected!** The Lambda has access to your PostgreSQL database.

Connection details are available as environment variables:
- `DB_HOST`: {{connections.database.auth.hostname}}
- `DB_PORT`: {{connections.database.auth.port}}
- `DB_NAME`: {{connections.database.auth.database}}
- `DB_USER`: {{connections.database.auth.username}}

To use persistent storage, update the Lambda code to use `psycopg2` or another PostgreSQL client.
{{/connections.database}}

{{^connections.database}}
**No database connected.** TODOs are stored in memory and will be lost when the Lambda cold starts.

To enable persistent storage, connect a PostgreSQL database to this package.
{{/connections.database}}

---

## Monitoring

### View Logs

```bash
aws logs tail /aws/lambda/{{artifacts.application.name}} --follow
```

### Check Function Status

```bash
aws lambda get-function \
  --function-name {{artifacts.application.name}} \
  --query 'Configuration.{State:State,LastModified:LastModified,MemorySize:MemorySize,Timeout:Timeout}'
```

### Invoke Directly (for testing)

```bash
aws lambda invoke \
  --function-name {{artifacts.application.name}} \
  --payload '{"httpMethod": "GET", "path": "/todos"}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/response.json && cat /tmp/response.json
```

---

## Troubleshooting

### Cold Starts

The first request after idle time may be slower (cold start). This is normal for Lambda.

### 502 Errors

Check CloudWatch logs for errors:
```bash
aws logs tail /aws/lambda/{{artifacts.application.name}} --since 5m
```

### Memory Issues

If you see out-of-memory errors, increase the Memory (MB) parameter and redeploy.
