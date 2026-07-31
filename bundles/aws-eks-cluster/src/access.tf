# The provisioner's assumed role needs an explicit access entry: access_config
# without bootstrap_cluster_creator_admin_permissions leaves the cluster
# creator with no Kubernetes identity in API_AND_CONFIG_MAP mode.
resource "aws_eks_access_entry" "provisioner" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.aws_authentication.arn
}

resource "aws_eks_access_policy_association" "provisioner_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.aws_authentication.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
