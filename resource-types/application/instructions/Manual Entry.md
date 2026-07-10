# Register an existing application

Use this form to register an application that was deployed outside Massdriver so other components can reference it.

## Application ID

Any stable, unique identifier for the deployment: a Kubernetes workload ID (`namespace/deployment-name`), a Lambda function ARN, or an internal service ID.

## URL

The URL where the application is reachable — public (`https://app.example.com`) or internal (`https://dashboard.internal.example.com`). Leave blank for workers with no HTTP endpoint.

## Health Check Path

The HTTP path that returns `200 OK` when the application is healthy, like `/healthz`. Defaults to `/`.
