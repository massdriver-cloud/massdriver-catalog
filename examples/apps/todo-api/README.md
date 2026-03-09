# Todo API

A simple REST API for managing todos, built with Go and Gin, storing data in PostgreSQL.

## Features

- CRUD operations for todos
- PostgreSQL storage
- Health check endpoint
- Automatic table creation
- ~15MB Docker image (scratch base)

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Full PostgreSQL connection string | - |
| `DATABASE_HOST` | Database host (fallback) | localhost |
| `DATABASE_PORT` | Database port (fallback) | 5432 |
| `DATABASE_NAME` | Database name (fallback) | postgres |
| `DATABASE_USER` | Database user (fallback) | postgres |
| `DATABASE_PASSWORD` | Database password (fallback) | - |
| `PORT` | Server port | 8080 |

If `DATABASE_URL` is set, it takes precedence. Otherwise, the connection string is built from the individual variables.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| GET | `/health` | Health check |
| GET | `/todos` | List all todos |
| POST | `/todos` | Create a todo |
| GET | `/todos/:id` | Get a todo |
| PUT | `/todos/:id` | Update a todo |
| DELETE | `/todos/:id` | Delete a todo |

## Example Requests

### Create a Todo

```bash
curl -X POST http://localhost:8080/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Buy groceries", "completed": false}'
```

### List Todos

```bash
curl http://localhost:8080/todos
```

### Update a Todo

```bash
curl -X PUT http://localhost:8080/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
```

### Delete a Todo

```bash
curl -X DELETE http://localhost:8080/todos/1
```

## Building

```bash
docker build -t massdrivercloud/todo-api:latest .
docker push massdrivercloud/todo-api:latest
```

## Running Locally

```bash
# With Docker
docker run -p 8080:8080 \
  -e DATABASE_URL="postgres://user:pass@host:5432/db" \
  massdrivercloud/todo-api:latest

# With Go
DATABASE_URL="postgres://user:pass@host:5432/db" go run main.go
```
