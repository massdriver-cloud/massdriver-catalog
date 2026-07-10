resource "massdriver_resource" "cluster" {
  field = "cluster"
  name  = "EKS ${var.md_metadata.name_prefix}"

  resource = jsonencode({
    id              = aws_eks_cluster.main.arn
    name            = aws_eks_cluster.main.name
    version         = aws_eks_cluster.main.version
    oidc_issuer_url = aws_eks_cluster.main.identity[0].oidc[0].issuer
    authentication = {
      cluster = {
        server                       = aws_eks_cluster.main.endpoint
        "certificate-authority-data" = aws_eks_cluster.main.certificate_authority[0].data
      }
      user = {
        token = data.aws_eks_cluster_auth.main.token
      }
    }
  })
}
