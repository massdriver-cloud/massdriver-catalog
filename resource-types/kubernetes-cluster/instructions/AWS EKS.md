# Importing an existing EKS cluster

Use this when you already have an EKS cluster and want Massdriver to know about it, instead of provisioning a new one with the `aws-eks-cluster` bundle.

## Where to find each field

1. Open the **EKS console** → your cluster → **Overview**.
   - `cluster_name`: the cluster's name.
   - `endpoint`: the "API server endpoint" field.
   - `ca_certificate`: **Overview** → **Certificate authority** (already base64-encoded — paste as-is).
   - `region`: the region shown in the top-right of the console.
2. Go to the cluster's **Access** tab → **OIDC provider URL**.
   - `oidc_provider_url`: the URL shown, with the leading `https://` stripped off.
   - `oidc_provider_arn`: in **IAM console** → **Identity providers**, find the provider matching that URL and copy its ARN.
3. Go to **Networking** tab.
   - `node_security_group_id`: the "Cluster security group" or your managed node group's security group ID.
4. If you've already installed an ingress controller (e.g. AWS Load Balancer Controller):
   - `ingress_class_name`: the `IngressClass` name it registers (`alb` by default for the AWS Load Balancer Controller).
   - `ingress_certificate_arn`: the ACM certificate ARN you intend apps to reference in their Ingress TLS annotations.

## Notes

- Workloads assume IAM roles via this cluster's OIDC provider (IRSA). Verify the OIDC provider ARN and URL match exactly; a mismatch causes role assumption to fail with `AccessDenied` at pod startup.
