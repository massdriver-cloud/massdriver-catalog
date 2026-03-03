terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
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

provider "google" {
  project     = var.gcp_authentication.project_id
  region      = var.region
  credentials = jsonencode(var.gcp_authentication)
}

resource "random_password" "main" {
  length  = 32
  special = false
}

locals {
  ha_enabled           = try(var.availability.high_availability, false)
  backup_enabled       = try(var.backup.enabled, true)
  pitr_enabled         = try(var.backup.point_in_time_recovery, false)
  postgres_version_num = replace(var.db_version, "POSTGRES_", "")
}

resource "google_sql_database_instance" "main" {
  name             = var.md_metadata.name_prefix
  database_version = var.db_version
  region           = var.region

  settings {
    tier              = var.tier
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true
    availability_type = local.ha_enabled ? "REGIONAL" : "ZONAL"

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.subnetwork.network_id
      enable_private_path_for_google_cloud_services = true
      require_ssl                                   = true
      ssl_mode                                      = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_hostname"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_min_messages"
      value = "warning"
    }

    database_flags {
      name  = "log_statement"
      value = "ddl"
    }

    database_flags {
      name  = "log_duration"
      value = "on"
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    backup_configuration {
      enabled                        = local.backup_enabled
      point_in_time_recovery_enabled = local.pitr_enabled
      start_time                     = "03:00"
      transaction_log_retention_days = local.pitr_enabled ? 7 : null

      backup_retention_settings {
        retained_backups = 7
      }
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = var.md_metadata.default_tags
  }

  deletion_protection = false
}

resource "google_sql_database" "main" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "main" {
  name     = var.username
  instance = google_sql_database_instance.main.name
  password = random_password.main.result
}
