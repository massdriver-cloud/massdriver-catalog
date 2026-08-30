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

# Connects as the shared cluster's admin user. That credential arrives from the
# `postgres_cluster` dependency and is never handed to the app — the app only ever
# receives the scoped login this bundle creates.
# `management_hostname` is set only when an operator has opted the instance into
# direct SQL management. Applications never use it — they take auth.hostname and
# reach the instance privately.
provider "postgresql" {
  host      = coalesce(var.postgres_cluster.management_hostname, var.postgres_cluster.auth.hostname)
  port      = var.postgres_cluster.auth.port
  database  = var.postgres_cluster.auth.database
  username  = var.postgres_cluster.auth.username
  password  = var.postgres_cluster.auth.password
  sslmode   = "require"
  superuser = false
}
