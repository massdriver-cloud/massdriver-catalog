resource "massdriver_artifact" "cluster" {
  field = "cluster"
  name  = "AWS EKS ${var.md_metadata.name_prefix}"
  artifact = jsonencode({
    id                        = local.cluster_arn
    name                      = var.cluster_name
    endpoint                  = local.endpoint
    certificate_authority     = base64encode("FAKE-CA-DATA-${random_pet.cluster.id}")
    region                    = var.vpc.region
    version                   = var.kubernetes_version
    vpc_id                    = var.vpc.id
    cluster_security_group_id = "sg-${substr(md5("${random_pet.cluster.id}-cluster"), 0, 17)}"
    fargate_profiles          = local.fargate_profiles
    oidc = {
      issuer       = local.oidc_issuer
      provider_arn = "arn:aws:iam::${var.vpc.account_id}:oidc-provider/oidc.eks.${var.vpc.region}.amazonaws.com/id/${upper(local.oidc_id)}"
    }
  })
}
