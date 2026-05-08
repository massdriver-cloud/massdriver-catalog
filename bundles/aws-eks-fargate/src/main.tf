data "aws_partition" "current" {}

locals {
  private_subnets = [for s in var.vpc.subnets : s.id if s.type == "private"]
  public_subnets  = [for s in var.vpc.subnets : s.id if s.type == "public"]
}

# --- Cluster IAM ---

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name_prefix        = "${var.cluster_name}-cluster-"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Cluster ---

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(local.private_subnets, local.public_subnets)
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# --- Fargate pod-execution role ---

data "aws_iam_policy_document" "fargate_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fargate" {
  name_prefix        = "${var.cluster_name}-fargate-"
  assume_role_policy = data.aws_iam_policy_document.fargate_assume.json
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution" {
  role       = aws_iam_role.fargate.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# --- Fargate profiles, one per namespace ---

resource "aws_eks_fargate_profile" "main" {
  for_each = toset(var.fargate_namespaces)

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "fp-${each.value}"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = local.private_subnets

  selector {
    namespace = each.value
  }

  timeouts {
    create = "30m"
    delete = "30m"
  }
}
