terraform {
  required_version = ">= 1.0"
  required_providers {
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 2.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.22"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Connects as the cluster's administrative user, which is the only login that can
# grant on tables it does not own. That credential comes from the dependency and is
# never handed to the app — the app receives the scoped login created here.
#
# `management_hostname` is set only when an operator has opted the instance into
# direct SQL management. Applications never use it.
provider "postgresql" {
  host      = coalesce(var.postgres_cluster.management_hostname, var.postgres_cluster.auth.hostname)
  port      = var.postgres_cluster.auth.port
  database  = var.postgres_cluster.auth.database
  username  = var.postgres_cluster.auth.username
  password  = var.postgres_cluster.auth.password
  sslmode   = "require"
  superuser = false
}
