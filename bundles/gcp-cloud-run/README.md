# gcp-cloud-run

Google Cloud Run is a fully managed serverless platform that automatically scales your stateless containers. This bundle deploys a Cloud Run service with optional VPC connectivity and database integration.

## Use Cases

- RESTful APIs and microservices
- Web applications and frontends
- Event-driven processing
- CI/CD automation services
- Development and staging environments

## Features

- Automatic scaling from 0 to N instances
- Built-in HTTPS endpoints
- VPC connectivity for private resources
- Database connection injection
- Zero-downtime deployments
- Pay-per-use pricing

## Design Decisions

### Serverless-First
Cloud Run is designed for stateless workloads that scale dynamically with traffic. It's ideal for:
- HTTP-based services
- Short-lived request handling
- Unpredictable or spiky traffic patterns

### VPC Integration
When a subnetwork is connected:
- Uses VPC Access Connector for egress to private IPs
- Enables access to Cloud SQL, GCE instances, and other VPC resources
- Maintains public internet access for external APIs

### Database Connectivity
Database credentials are automatically injected as environment variables when a PostgreSQL database is connected, simplifying application configuration.

### API Enablement
The bundle automatically enables the Cloud Run API to ensure smooth deployments without manual setup.

## Configuration

### Basic Web Service
```yaml
region: us-central1
container:
  image: gcr.io/cloudrun/hello
  port: 8080
  cpu: "1"
  memory: 512Mi
scaling:
  min_instances: 0  # Scale to zero
  max_instances: 10
ingress: all  # Public access
```

### Private API with Database
```yaml
region: us-central1
container:
  image: gcr.io/myproject/api:latest
  port: 3000
  cpu: "2"
  memory: 1Gi
  env:
    - name: NODE_ENV
      value: production
scaling:
  min_instances: 1  # Always-on
  max_instances: 100
ingress: internal  # VPC only
connections:
  subnetwork: <gcp-subnetwork-artifact>
  database: <postgres-artifact>
```

## Compliance

This bundle passes all Checkov security policies with no findings or muted checks.

## Trade-offs

### Pros
- Zero infrastructure management
- Pay only for actual usage
- Automatic scaling and load balancing
- Built-in SSL/TLS termination

### Cons
- Cold start latency (mitigated with min_instances > 0)
- Request timeout limits (max 60 minutes)
- No persistent local storage
- Requires containerized applications

## Learn More

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Container Best Practices](https://cloud.google.com/run/docs/tips/general)
- [VPC Access](https://cloud.google.com/run/docs/configuring/vpc-direct-vpc)
- [Pricing](https://cloud.google.com/run/pricing)
