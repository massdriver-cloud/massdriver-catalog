resource "massdriver_artifact" "kubernetes_cluster" {
  field = "kubernetes_cluster"
  name  = "EKS Fargate ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    data = {
      infrastructure = {
        arn             = aws_eks_cluster.main.arn
        oidc_issuer_url = aws_eks_cluster.main.identity[0].oidc[0].issuer
      }
      authentication = {
        cluster = {
          server                       = aws_eks_cluster.main.endpoint
          "certificate-authority-data" = aws_eks_cluster.main.certificate_authority[0].data
        }
        user = {
          token = "" # Users will configure access via AWS IAM or service account tokens
        }
      }
    }
    specs = {
      kubernetes = {
        version      = var.kubernetes_version
        cloud        = "aws"
        distribution = "eks"
        platform_config = {
          fargate_enabled = true
        }
      }
      aws = {
        region = var.vpc.region
      }
    }
  })
}
