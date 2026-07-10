# Register an existing EKS cluster

Use this form to register an EKS cluster that was created outside Massdriver so bundles can deploy onto it.

You'll need the AWS CLI and `kubectl` configured for the cluster.

## Cluster ID

```bash
aws eks describe-cluster --name YOUR_CLUSTER --query cluster.arn --output text
```

## Cluster Name

The cluster name as shown in the EKS console.

## Kubernetes Version

```bash
aws eks describe-cluster --name YOUR_CLUSTER --query cluster.version --output text
```

## OIDC Issuer URL

```bash
aws eks describe-cluster --name YOUR_CLUSTER --query cluster.identity.oidc.issuer --output text
```

## Authentication → Cluster → Server

```bash
aws eks describe-cluster --name YOUR_CLUSTER --query cluster.endpoint --output text
```

## Authentication → Cluster → CA Data

```bash
aws eks describe-cluster --name YOUR_CLUSTER --query cluster.certificateAuthority.data --output text
```

## Authentication → User → Token

Create a long-lived service account token for Massdriver deployments (the short-lived `aws eks get-token` output expires in minutes — don't paste that here):

```bash
kubectl create serviceaccount massdriver -n kube-system
kubectl create clusterrolebinding massdriver --clusterrole=cluster-admin --serviceaccount=kube-system:massdriver
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: massdriver-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: massdriver
type: kubernetes.io/service-account-token
EOF
kubectl get secret massdriver-token -n kube-system -o jsonpath='{.data.token}' | base64 -d
```

Scope the role binding down from `cluster-admin` to match your team's policy.
