# AWS EKS Fargate

Serverless Kubernetes cluster using AWS EKS with Fargate profiles. No EC2 instances to manage - pods run directly on Fargate.

## Features

- **Serverless Kubernetes** - No node management, automatic scaling
- **Fargate Profiles** - Pods run on AWS Fargate compute
- **IRSA Support** - IAM Roles for Service Accounts via OIDC
- **Control Plane Logging** - Full audit and API logging to CloudWatch
- **Private/Public Endpoints** - Configurable API server access

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │           EKS Control Plane         │
                    │  (Managed by AWS, multi-AZ)         │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
    ┌─────────▼─────────┐ ┌───────▼───────┐ ┌─────────▼─────────┐
    │  Fargate Profile  │ │Fargate Profile│ │  Fargate Profile  │
    │    (default)      │ │ (kube-system) │ │   (custom ns)     │
    └─────────┬─────────┘ └───────┬───────┘ └─────────┬─────────┘
              │                   │                   │
    ┌─────────▼─────────┐ ┌───────▼───────┐ ┌─────────▼─────────┐
    │   Your Pods       │ │   CoreDNS     │ │   Your Pods       │
    │   (Fargate)       │ │   (Fargate)   │ │   (Fargate)       │
    └───────────────────┘ └───────────────┘ └───────────────────┘
```

## Connections

| Name | Type | Description |
|------|------|-------------|
| `aws_authentication` | `aws-iam-role` | AWS credentials for deployment |
| `vpc` | `aws-vpc` | VPC with private subnets for Fargate |

## Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | string | `eks-fargate` | Name for your EKS cluster |
| `kubernetes_version` | string | `1.29` | Kubernetes version |
| `fargate_namespaces` | array | `[]` | Additional namespaces for Fargate (default/kube-system always included) |
| `endpoint_public_access` | boolean | `true` | Enable public API access |
| `endpoint_private_access` | boolean | `true` | Enable private API access |

## Outputs

- `kubernetes_cluster` - Kubernetes cluster artifact with connection details

## Usage Notes

### Fargate Considerations

- **No DaemonSets** - Fargate doesn't support DaemonSets
- **Pod limits** - Max 4 vCPU, 30GB memory per pod
- **Persistent volumes** - Use EFS (EBS not supported on Fargate)
- **Startup time** - Fargate pods take ~30-60s longer to start than EC2

### Accessing the Cluster

After deployment, configure kubectl:

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

### Deploying Workloads

Pods in namespaces with Fargate profiles automatically run on Fargate:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: default  # Has Fargate profile
spec:
  containers:
    - name: app
      image: nginx
```

## Changelog

### 0.0.1

- Initial release
- EKS cluster with Fargate profiles
- OIDC provider for IRSA
- Control plane logging enabled
