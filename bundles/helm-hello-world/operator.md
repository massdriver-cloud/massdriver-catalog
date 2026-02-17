# Hello World Operator Guide

This bundle deploys a simple nginx-based hello-world application to your Kubernetes cluster.

## Accessing the Service

The hello-world service runs on port 80 with ClusterIP. To access it:

### Using kubectl port-forward

1. First, configure kubectl to connect to your EKS cluster:

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

2. Port-forward to the service:

```bash
kubectl port-forward svc/<name-prefix>-hello 8080:80 -n <namespace>
```

3. Open http://localhost:8080 in your browser

### Finding the service name

The service name follows the pattern: `<name-prefix>-hello`

Where `<name-prefix>` is the Massdriver-generated name prefix for your package.

You can find all services with:

```bash
kubectl get svc -n <namespace>
```

## Configuration

| Parameter | Description |
|-----------|-------------|
| `namespace` | Kubernetes namespace to deploy into |
| `replicas` | Number of pod replicas |
| `message` | Custom message (displayed in env var) |

## Troubleshooting

### Pods not starting

Check pod status:

```bash
kubectl get pods -n <namespace> -l app=hello-world
kubectl describe pod -n <namespace> -l app=hello-world
```

### Fargate scheduling

On EKS Fargate, pods must be scheduled in namespaces with a matching Fargate profile. The default namespace should work if configured in the EKS cluster.
