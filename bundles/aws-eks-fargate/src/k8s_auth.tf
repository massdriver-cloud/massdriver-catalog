# A long-lived bearer token bound to a cluster-admin ServiceAccount. EKS only
# issues short-lived tokens via aws eks get-token (~15 min); a token Secret
# bound to a ServiceAccount is what kubectl, helm, or any out-of-band
# automation can use without refreshing.

resource "kubernetes_service_account" "massdriver" {
  metadata {
    name      = "massdriver"
    namespace = "kube-system"
  }
  depends_on = [aws_eks_fargate_profile.main]
}

resource "kubernetes_cluster_role_binding" "massdriver" {
  metadata {
    name = "massdriver-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.massdriver.metadata[0].name
    namespace = kubernetes_service_account.massdriver.metadata[0].namespace
  }
}

resource "kubernetes_secret" "massdriver_token" {
  metadata {
    name      = "massdriver-token"
    namespace = kubernetes_service_account.massdriver.metadata[0].namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.massdriver.metadata[0].name
    }
  }
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}
