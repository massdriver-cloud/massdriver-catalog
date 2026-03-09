---
templating: mustache
---

# Todo API Operator Guide

## Service Info

**Service URL:** `{{artifacts.service.service_url}}`

## Building and Pushing the Image

```bash
cd examples/apps/todo-api

# Build the image
docker build -t <your-dockerhub-username>/todo-api:latest .

# Push to Docker Hub
docker push <your-dockerhub-username>/todo-api:latest
```

## API Usage

### Health Check

```bash
curl {{artifacts.service.service_url}}/
```

### Create a Todo

```bash
curl -X POST {{artifacts.service.service_url}}/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy groceries", "completed": false}'
```

### List Todos

```bash
curl {{artifacts.service.service_url}}/todos
```

### Get a Todo

```bash
curl {{artifacts.service.service_url}}/todos/1
```

### Update a Todo

```bash
curl -X PUT {{artifacts.service.service_url}}/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
```

### Delete a Todo

```bash
curl -X DELETE {{artifacts.service.service_url}}/todos/1
```

## Logs

```bash
gcloud run services logs read {{artifacts.service.name}} --region {{params.region}} --limit=100
```
