# AWS Load Balancer Controller: watches Ingress resources across every app
# sharing this cluster and provisions one ALB per Ingress, terminating TLS
# with the ACM certificate apps reference in their Ingress annotations.

resource "aws_iam_role" "alb_controller" {
  name_prefix = "${local.name_prefix}-alb-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.main.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${aws_iam_openid_connect_provider.main.url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${aws_iam_openid_connect_provider.main.url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = var.md_metadata.default_tags
}

# NOTE: this is a reduced version of AWS's published aws-load-balancer-controller
# IAM policy — covers the actions the controller needs for the common ALB/target-group
# lifecycle used in this demo. Pull the full, current policy from
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
# before running this in production; AWS revises it as the controller adds features.
resource "aws_iam_policy" "alb_controller" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Reduced AWS Load Balancer Controller policy — see NOTE in ingress.tf before using in production."
  policy      = file("${path.module}/aws-load-balancer-controller-iam-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }
  set {
    name  = "region"
    value = var.network.region
  }
  set {
    name  = "vpcId"
    value = var.network.vpc_id
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }

  depends_on = [aws_eks_node_group.main, aws_eks_access_policy_association.provisioner_admin]
}
