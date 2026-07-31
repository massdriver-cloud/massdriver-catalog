terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.4"
    }
  }
}

provider "aws" {
  region = var.cluster.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = var.aws_authentication.external_id
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

# The EKS auth token only needs the cluster name — it doesn't require the
# aws_eks_cluster resource to exist in this bundle's own state, just the
# connected cluster's name and this bundle's own AWS credentials.
data "aws_eks_cluster_auth" "this" {
  name = var.cluster.cluster_name
}

provider "kubernetes" {
  host                   = var.cluster.endpoint
  cluster_ca_certificate = base64decode(var.cluster.ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}
