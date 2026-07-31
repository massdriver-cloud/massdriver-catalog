resource "massdriver_resource" "cluster" {
  field = "cluster"
  name  = "EKS Cluster (${var.md_metadata.name_prefix})"
  resource = jsonencode({
    cluster_name            = aws_eks_cluster.main.name
    endpoint                = aws_eks_cluster.main.endpoint
    ca_certificate          = aws_eks_cluster.main.certificate_authority[0].data
    region                  = var.network.region
    oidc_provider_arn       = aws_iam_openid_connect_provider.main.arn
    oidc_provider_url       = replace(aws_iam_openid_connect_provider.main.url, "https://", "")
    node_security_group_id  = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ingress_class_name      = "alb"
    ingress_certificate_arn = var.acm_certificate_arn
  })

  depends_on = [helm_release.alb_controller]
}
