terraform {
  required_version = ">= 1.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.4"
    }
  }
}

provider "kubernetes" {
  host                   = var.kubernetes_cluster.authentication.cluster.server
  cluster_ca_certificate = base64decode(var.kubernetes_cluster.authentication.cluster["certificate-authority-data"])
  token                  = var.kubernetes_cluster.authentication.user.token
}

provider "helm" {
  kubernetes {
    host                   = var.kubernetes_cluster.authentication.cluster.server
    cluster_ca_certificate = base64decode(var.kubernetes_cluster.authentication.cluster["certificate-authority-data"])
    token                  = var.kubernetes_cluster.authentication.user.token
  }
}

resource "kubernetes_namespace" "main" {
  metadata {
    name = var.md_metadata.name_prefix

    # The selected database access policy travels with the workload. Platform
    # tooling (or the DBA at 2am) can see what access level this app requested
    # without opening the Massdriver UI. WordPress itself connects with the
    # single user from the database connection.
    annotations = {
      "massdriver.cloud/database-policy" = var.database_policy
    }
  }
}

# The admin password the Helm chart seeds WordPress with. The
# WORDPRESS_ADMIN_PASSWORD app secret gates deploys in the UI and is injected
# into the app's runtime environment — app secrets never pass through
# Terraform. See the README for how the two relate.
resource "random_password" "wordpress_admin" {
  length  = 24
  special = false
}

resource "helm_release" "wordpress" {
  name       = var.md_metadata.name_prefix
  namespace  = kubernetes_namespace.main.metadata[0].name
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "wordpress"
  version    = "24.1.5"

  # Deterministic resource names regardless of what the release name contains,
  # so the artifact and runbook can point at "<name_prefix>" directly.
  set {
    name  = "fullnameOverride"
    value = var.md_metadata.name_prefix
  }

  set {
    name  = "wordpressBlogName"
    value = var.blog_title
  }

  set {
    name  = "wordpressUsername"
    value = var.admin_username
  }

  set {
    name  = "wordpressEmail"
    value = var.admin_email
  }

  set_sensitive {
    name  = "wordpressPassword"
    value = random_password.wordpress_admin.result
  }

  set {
    name  = "replicaCount"
    value = tostring(var.replicas)
  }

  set {
    name  = "service.type"
    value = var.service_type
  }

  # Use the linked database instead of the chart's bundled MariaDB.
  set {
    name  = "mariadb.enabled"
    value = "false"
  }

  set {
    name  = "externalDatabase.host"
    value = var.database.auth.hostname
  }

  set {
    name  = "externalDatabase.port"
    value = tostring(var.database.auth.port)
  }

  set {
    name  = "externalDatabase.user"
    value = var.database.auth.username
  }

  set {
    name  = "externalDatabase.database"
    value = var.database.auth.database
  }

  set_sensitive {
    name  = "externalDatabase.password"
    value = var.database.auth.password
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "10Gi"
  }
}

# Only read the service when a cloud load balancer is expected. helm_release
# waits for the LoadBalancer address by default, so the status is populated
# by the time this reads.
data "kubernetes_service" "wordpress" {
  count = var.service_type == "LoadBalancer" ? 1 : 0

  metadata {
    name      = var.md_metadata.name_prefix
    namespace = kubernetes_namespace.main.metadata[0].name
  }

  depends_on = [helm_release.wordpress]
}

locals {
  lb_ingress = var.service_type == "LoadBalancer" ? try(data.kubernetes_service.wordpress[0].status[0].load_balancer[0].ingress[0], null) : null
  lb_host    = local.lb_ingress != null ? try(coalesce(local.lb_ingress.hostname, local.lb_ingress.ip), "") : ""
  url        = local.lb_host != "" ? "http://${local.lb_host}" : null
}
