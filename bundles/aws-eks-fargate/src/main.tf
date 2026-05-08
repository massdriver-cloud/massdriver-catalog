terraform {
  required_version = ">= 1.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

resource "random_pet" "cluster" {
  length = 2
  keepers = {
    cluster_name       = var.cluster_name
    kubernetes_version = var.kubernetes_version
    vpc_id             = var.vpc.id
  }
}

locals {
  cluster_arn = "arn:aws:eks:${var.vpc.region}:${var.vpc.account_id}:cluster/${var.cluster_name}"
  endpoint    = "https://${random_pet.cluster.id}.gr7.${var.vpc.region}.eks.amazonaws.com"
  oidc_id     = substr(md5(random_pet.cluster.id), 0, 32)
  oidc_issuer = "https://oidc.eks.${var.vpc.region}.amazonaws.com/id/${upper(local.oidc_id)}"

  fargate_profiles = [for ns in var.fargate_namespaces : {
    name      = "fp-${ns}"
    namespace = ns
  }]
}
