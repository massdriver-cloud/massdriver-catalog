# Kubernetes Deployment + Service + Ingress on the shared EKS cluster, plus
# optional CronJobs for scheduled work — the one designated compute unit for
# this component. Connection-derived env vars (DATABASE_URL, STORAGE_BUCKET,
# etc.) are injected by the platform via the `app.envs` block in
# massdriver.yaml, not through Terraform — this file only shapes the pods
# themselves and the IAM identity they run as.
#
# database / storage / queue / cache / email are all OPTIONAL connections.
# When you generate a real app's bundle from this template, delete whichever
# of these blocks (and the matching massdriver.yaml connection + app.envs
# lines) that app doesn't use.

locals {
  namespace            = lower(var.md_metadata.name_prefix)
  app_name             = "app"
  service_account_name = "app"

  has_storage = var.storage != null
  has_queue   = var.queue != null

  storage_policy_arn = local.has_storage && var.storage_policy != "" ? {
    for p in var.storage.policies : p.name => p.id
  }[var.storage_policy] : null

  queue_policy_arn = local.has_queue && var.queue_policy != "" ? {
    for p in var.queue.policies : p.name => p.id
  }[var.queue_policy] : null
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = local.namespace
  }
}

# --- IRSA: this app's pods get a scoped IAM identity through their service
#     account, never a static AWS access key. ---

resource "aws_iam_role" "irsa" {
  name_prefix = "${var.md_metadata.name_prefix}-irsa-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.cluster.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.cluster.oidc_provider_url}:sub" = "system:serviceaccount:${local.namespace}:${local.service_account_name}"
          "${var.cluster.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = var.md_metadata.default_tags
}

resource "aws_iam_role_policy_attachment" "storage" {
  count      = local.has_storage && local.storage_policy_arn != null ? 1 : 0
  role       = aws_iam_role.irsa.name
  policy_arn = local.storage_policy_arn
}

resource "aws_iam_role_policy_attachment" "queue" {
  count      = local.has_queue && local.queue_policy_arn != null ? 1 : 0
  role       = aws_iam_role.irsa.name
  policy_arn = local.queue_policy_arn
}

resource "kubernetes_service_account" "app" {
  metadata {
    name      = local.service_account_name
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.irsa.arn
    }
  }
}

# --- Compute ---

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = { app = local.app_name }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = local.app_name }
    }

    template {
      metadata {
        labels = { app = local.app_name }
      }

      spec {
        service_account_name = kubernetes_service_account.app.metadata[0].name

        container {
          name  = local.app_name
          image = var.image

          port {
            container_port = var.container_port
          }

          resources {
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.health_check_path
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = var.health_check_path
              port = var.container_port
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = { app = local.app_name }
    type     = "ClusterIP"

    port {
      port        = 80
      target_port = var.container_port
    }
  }
}

resource "kubernetes_ingress_v1" "app" {
  metadata {
    name      = local.app_name
    namespace = kubernetes_namespace.app.metadata[0].name
    annotations = merge(
      {
        "kubernetes.io/ingress.class"                = var.cluster.ingress_class_name
        "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"      = "ip"
        "alb.ingress.kubernetes.io/healthcheck-path" = var.health_check_path
      },
      var.cluster.ingress_certificate_arn != "" ? {
        "alb.ingress.kubernetes.io/certificate-arn" = var.cluster.ingress_certificate_arn
        "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
        "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
        } : {
        "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }])
      }
    )
  }

  spec {
    ingress_class_name = var.cluster.ingress_class_name

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# --- Scheduled work ---

resource "kubernetes_cron_job_v1" "jobs" {
  for_each = { for j in var.cronjobs : j.name => j }

  metadata {
    name      = each.key
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    schedule = each.value.schedule

    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = kubernetes_service_account.app.metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name    = each.key
              image   = var.image
              command = each.value.command
            }
          }
        }
      }
    }
  }
}
