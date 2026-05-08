resource "massdriver_artifact" "kubernetes_cluster" {
  field = "kubernetes_cluster"
  name  = "AWS EKS ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id                    = aws_eks_cluster.main.arn
    name                  = aws_eks_cluster.main.name
    endpoint              = aws_eks_cluster.main.endpoint
    certificate_authority = aws_eks_cluster.main.certificate_authority[0].data
    region                = var.vpc.region
    version               = aws_eks_cluster.main.version
    vpc_id                = var.vpc.id
    fargate_profiles = [
      for ns, fp in aws_eks_fargate_profile.main : {
        name      = fp.fargate_profile_name
        namespace = ns
      }
    ]
    token = lookup(kubernetes_secret.massdriver_token.data, "token", "")
  })
}
