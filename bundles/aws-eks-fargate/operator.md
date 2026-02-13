---
templating: mustache
---

# EKS Fargate Cluster - Operator Guide

## Cluster Details

**Cluster Name:** `{{params.cluster_name}}`
**Kubernetes Version:** `{{params.kubernetes_version}}`
**Region:** `{{connections.vpc.region}}`

---

## Connect to Cluster

### Configure kubectl

```bash
aws eks update-kubeconfig \
  --name {{params.cluster_name}} \
  --region {{connections.vpc.region}}
```

### Verify Connection

```bash
kubectl get nodes
kubectl get pods -A
```

---

## Fargate Namespaces

Pods in these namespaces run on Fargate:

- `default`
- `kube-system`
{{#params.fargate_namespaces}}
- `{{.}}`
{{/params.fargate_namespaces}}

---

## Deploy a Test Workload

```bash
kubectl run nginx --image=nginx --namespace=default
kubectl get pods -w
```

Watch for the pod to transition through:
1. `Pending` (Fargate scheduling)
2. `ContainerCreating` (pulling image)
3. `Running`

---

## Monitoring

### View Cluster Logs

```bash
aws logs tail /aws/eks/{{params.cluster_name}}/cluster --follow
```

### Check Fargate Profiles

```bash
aws eks list-fargate-profiles --cluster-name {{params.cluster_name}}
```

### View Pod Resource Usage

```bash
kubectl top pods -A
```

---

## Troubleshooting

### Pod Stuck in Pending

Check if the namespace has a Fargate profile:

```bash
aws eks describe-fargate-profile \
  --cluster-name {{params.cluster_name}} \
  --fargate-profile-name {{params.cluster_name}}-default
```

### CoreDNS Issues

CoreDNS runs on Fargate. Check its status:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### Node Not Showing

Fargate nodes appear only when pods are scheduled:

```bash
kubectl get nodes -o wide
```

---

## IAM Roles for Service Accounts (IRSA)

Create a service account with IAM permissions:

```bash
eksctl create iamserviceaccount \
  --cluster={{params.cluster_name}} \
  --namespace=default \
  --name=my-service-account \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve
```

---

## Resource Limits

Fargate pod limits:
- **Max vCPU:** 4
- **Max Memory:** 30GB
- **Storage:** 20GB ephemeral (expandable via EFS)

Supported CPU/Memory combinations:
| vCPU | Memory Options (GB) |
|------|---------------------|
| 0.25 | 0.5, 1, 2 |
| 0.5  | 1, 2, 3, 4 |
| 1    | 2, 3, 4, 5, 6, 7, 8 |
| 2    | 4-16 (1GB increments) |
| 4    | 8-30 (1GB increments) |
