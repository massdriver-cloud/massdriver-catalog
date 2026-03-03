# GCP Cloud Run Operator Guide

## Overview

This bundle deploys a Google Cloud Run service, a fully managed serverless platform for running containerized applications. Cloud Run automatically scales your containers up and down based on traffic, and you only pay for what you use.

## Architecture

The bundle creates:
- **Cloud Run v2 Service**: Serverless container runtime
- **VPC Connector**: Private network access when subnetwork is connected
- **IAM Bindings**: Public or private access controls based on ingress settings
- **API Enablement**: Automatically enables the Cloud Run API

## Connections

### Required
- **gcp_authentication**: GCP service account credentials for provisioning resources

### Optional
- **subnetwork**: GCP subnetwork for VPC-native networking
  - Enables private communication with Cloud SQL, VMs, and other VPC resources
  - Uses VPC Access Connector for egress to private IP ranges
- **database**: PostgreSQL database connection
  - Automatically injects database connection environment variables:
    - `DATABASE_HOST`
    - `DATABASE_PORT`
    - `DATABASE_NAME`
    - `DATABASE_USER`
    - `DATABASE_PASSWORD`
    - `DATABASE_URL` (connection string)

## Parameters

### Region
GCP region where the Cloud Run service will be deployed. Should match your subnetwork and database region for optimal latency.

### Container Configuration

**Image**: Full container image URL (e.g., `gcr.io/project/image:tag`)
- Must be accessible by the service account
- Common registries: GCR, Artifact Registry, Docker Hub

**Port**: Container port your application listens on (default: 8080)
- Cloud Run routes HTTP/HTTPS traffic to this port
- Must match your application's configuration

**CPU**: CPU cores allocated per container instance
- Options: 1, 2, or 4 cores
- More CPU = higher throughput, higher cost

**Memory**: RAM allocated per container instance
- Options: 256Mi, 512Mi, 1Gi, 2Gi, 4Gi
- Must be sufficient for your application's needs
- Consider memory leaks and peak usage

**Environment Variables**: Key-value pairs injected into the container
- Use for non-sensitive configuration
- Database credentials are auto-injected if database is connected
- For secrets, use Google Secret Manager integration

### Scaling Configuration

**Minimum Instances**: Number of instances always running
- 0 = scale to zero (cost-effective for intermittent workloads)
- 1+ = keep instances warm (lower cold start latency)

**Maximum Instances**: Upper limit on concurrent instances
- Prevents runaway costs during traffic spikes
- Consider quotas and downstream service capacity

### Ingress

Controls who can reach your service:
- **all**: Public internet access (default)
- **internal**: Only from same VPC and project
- **internal-and-cloud-load-balancing**: VPC + Cloud Load Balancer

## Artifacts

### service (application)
Application artifact containing Cloud Run service details:
- **name**: Cloud Run service name
- **deployment_id**: Unique deployment identifier
- **service_url**: HTTPS endpoint for the service
- **tags**: Resource labels

Use this artifact to:
- Connect other services to this Cloud Run endpoint
- Build deployment dashboards
- Track service dependencies

## Operations

### Viewing Logs
```bash
# Via gcloud CLI
gcloud run services logs tail <service-name> --region=<region>

# Via Massdriver
mass logs <deployment-id>
```

### Accessing the Service

For public services (ingress=all):
```bash
# Get the service URL
mass pkg get <project>-<env>-<manifest> -o json | jq -r '.artifacts[0].name'

# Visit the URL in your browser or curl
curl https://<service-name>-<hash>-<region>.run.app
```

For private services:
- Access from resources in the same VPC
- Use Cloud Load Balancer with IAM authentication

### Monitoring

Cloud Run provides built-in metrics:
- Request count
- Request latency
- Container CPU/memory utilization
- Instance count
- Billable time

Access via Google Cloud Console > Cloud Run > [Service] > Metrics

### Updating the Service

Changes to any parameters trigger a new revision:
1. Update parameters in Massdriver UI
2. Deploy the package
3. Cloud Run creates a new revision with zero downtime
4. Traffic gradually shifts to the new revision

### Database Connectivity

When a PostgreSQL database is connected:
1. Ensure the database is in the same region (or use HA replica)
2. Connect a subnetwork to enable private IP access
3. Database credentials are automatically injected as environment variables
4. Use the `DATABASE_URL` env var in your application:
   ```python
   # Example: Python with psycopg2
   import os
   import psycopg2

   conn = psycopg2.connect(os.environ['DATABASE_URL'])
   ```

### VPC Connectivity

When a subnetwork is connected:
1. Cloud Run uses a VPC Access Connector
2. Egress to private IP ranges routes through the VPC
3. Public internet access remains available
4. Can access Cloud SQL via private IP, internal load balancers, etc.

## Troubleshooting

### Service Won't Start
- Check container logs for application errors
- Verify the container listens on the configured port
- Ensure sufficient memory/CPU resources
- Check that Cloud Run API is enabled (auto-enabled by this bundle)

### Can't Access Database
- Verify subnetwork is connected
- Ensure database is in the same region
- Check database firewall rules (should allow VPC CIDR)
- Confirm VPC Access Connector is provisioned

### Cold Start Latency
- Set min_instances >= 1 to keep instances warm
- Optimize container startup time
- Use Alpine or distroless base images
- Consider Cloud Run (gen1) for faster cold starts

### High Costs
- Check max_instances limit
- Review scaling metrics (may be getting too much traffic)
- Enable scale-to-zero (min_instances=0) for dev/staging
- Optimize container memory footprint

### 403 Forbidden
- For public services: verify ingress="all"
- Check IAM bindings (allUsers should have roles/run.invoker)
- For private services: ensure requests include valid auth token

## Security Best Practices

1. **Use Private Ingress**: Set ingress to "internal" for non-public services
2. **Enable VPC**: Connect subnetwork for private database access
3. **Environment Variables**: Never commit secrets to container images
4. **Service Account**: Use least-privilege service accounts
5. **HTTPS Only**: Cloud Run enforces HTTPS by default
6. **Binary Authorization**: Consider enabling for production workloads

## Compliance

This bundle passes all Checkov security policies for:
- Cloud Run service configuration
- IAM permissions
- API enablement

No muted checks or compliance warnings.

## Cost Optimization

- **Scale to Zero**: Use min_instances=0 for dev/test workloads
- **Right-size Resources**: Start with 512Mi/1 CPU and monitor actual usage
- **Regional Selection**: Choose regions close to users and data
- **Request Batching**: Process multiple items per request to reduce instance churn

## Support

For issues with:
- **Bundle**: Open an issue in the massdriver-catalog repository
- **Cloud Run**: Check Google Cloud Run documentation
- **Deployment**: Contact Massdriver support with deployment ID
