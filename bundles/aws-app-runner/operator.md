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
docker build -t todo-api:latest .

# Login to ECR Public
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws

# Tag for ECR Public (replace <alias> with your registry alias)
docker tag todo-api:latest public.ecr.aws/<alias>/todo-api:latest

# Push to ECR Public
docker push public.ecr.aws/<alias>/todo-api:latest
```

To get your registry alias:
```bash
aws ecr-public describe-registries --region us-east-1 --query 'registries[0].aliases[0].name' --output text
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
aws logs tail /aws/apprunner/{{artifacts.service.name}}/{{artifacts.service.deployment_id}}/application --follow
```
