// Cloud SQL enforces a cooldown on reusing a just-deleted instance's name —
// recreating an instance with the same name shortly after tearing it down
// fails (observed directly: the provider surfaces this as an opaque "Error
// waiting for Create Instance" with no detail). md_metadata.name_prefix is
// stable for the life of a massdriver instance, so without this suffix a
// destroy immediately followed by a re-provision — a full recreate to pick
// up an immutable field change, or a decommission/redeploy cycle — would
// always collide with the name it just freed up. random_id has no keepers,
// so it stays fixed across ordinary in-place param updates (no spurious
// renames) but generates a fresh value whenever the resource itself is
// destroyed and recreated, sidestepping the cooldown automatically.
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  # google_sql_database_instance names allow up to 98 characters, far more
  # than name_prefix ever produces, but every other bundle in this catalog
  # trims defensively rather than assuming — cheap insurance against a very
  # long project/environment/component id combination.
  instance_name = trimsuffix(substr("pg-${var.md_metadata.name_prefix}-${random_id.suffix.hex}", 0, 63), "-")

  # "How much traffic do you expect?" maps to a real GCP custom machine type.
  # These are valid db-custom tiers (1 vCPU : 3840 MiB ratio, doubled each
  # step) — developers pick a plain-English size, never a machine type string.
  tier_by_size = {
    small  = "db-custom-1-3840"
    medium = "db-custom-2-7680"
    large  = "db-custom-4-15360"
  }
  tier = local.tier_by_size[var.size]
}

resource "google_project_service" "sqladmin" {
  project            = var.gcp_service_account.project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_sql_database_instance" "main" {
  name                = local.instance_name
  project             = var.gcp_service_account.project_id
  region              = var.region
  database_version    = var.postgres_version
  deletion_protection = var.prevent_accidental_deletion

  settings {
    # Explicit because the API's account-level default edition is
    # ENTERPRISE_PLUS in some projects, which rejects db-custom-* tiers
    # outright ("Invalid Tier ... Use a predefined Tier like
    # db-perf-optimized-N-* instead"). ENTERPRISE is the standard edition
    # our tier_by_size machine types are valid for.
    edition           = "ENTERPRISE"
    tier              = local.tier
    disk_size         = var.storage_gb
    disk_type         = "PD_SSD"
    disk_autoresize   = true
    availability_type = var.keep_running_if_a_zone_fails ? "REGIONAL" : "ZONAL"

    # Private by default: apps reach this instance over the platform network's
    # Private Service Access peering and nothing else can see it. A public IP
    # appears only when an operator lists an address in iac_authorized_networks,
    # which exists because schema and table grants have to be issued over a SQL
    # connection — the Google Cloud API cannot express them. Anything not on the
    # list is refused, and ssl_mode keeps every connection encrypted either way.
    ip_configuration {
      ipv4_enabled    = length(var.iac_authorized_networks) > 0
      private_network = var.network.self_link
      ssl_mode        = "ENCRYPTED_ONLY"

      dynamic "authorized_networks" {
        for_each = var.iac_authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.cidr
        }
      }
    }

    backup_configuration {
      enabled                        = var.keep_backups
      point_in_time_recovery_enabled = var.keep_backups
      transaction_log_retention_days = var.keep_backups ? 7 : 1
      backup_retention_settings {
        retained_backups = var.keep_backups ? 30 : 1
      }
    }

    # Audit-grade logging posture, hardcoded rather than exposed as params —
    # there's no legitimate reason any environment, including a developer's
    # own sandbox, would want query/connection auditing turned off. Unlike
    # size or HA, this isn't a cost/latency trade-off.
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_checkpoints"
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
      name  = "log_min_error_statement"
      value = "error"
    }
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }
    database_flags {
      name  = "log_duration"
      value = "on"
    }
    database_flags {
      name  = "log_hostname"
      value = "on"
    }
    # Logs DDL statements (schema changes) unconditionally rather than every
    # statement — "all" would also capture ordinary application queries,
    # which can include customer data in bind parameters. DDL-level logging
    # gives a real audit trail of schema/permission changes without that
    # cost/exposure trade-off, so it's hardcoded rather than a param.
    database_flags {
      name  = "log_statement"
      value = "ddl"
    }
    # pgAudit gives object-level audit logging beyond what log_statement
    # covers. Enabling the flag loads the extension; it still needs
    # `CREATE EXTENSION IF NOT EXISTS pgaudit;` run once against the database
    # itself to activate — this bundle's provisioner has no path onto the
    # private network to run that statement (see operator.md).
    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }
    database_flags {
      name  = "pgaudit.log"
      value = "all"
    }
  }

  depends_on = [google_project_service.sqladmin]

  lifecycle {
    precondition {
      # private_service_access is optional on the network resource type (a
      # hand-created or imported network resource might omit it entirely) —
      # try() treats that the same as "not enabled" rather than erroring on
      # a null comparison.
      condition     = try(var.network.private_service_access, false)
      error_message = "The connected network doesn't have Private Service Access enabled, so this database can't get a private IP. Turn on 'Private Service Access' on the gcp-network component and redeploy it before deploying this database."
    }
  }
}

resource "google_sql_database" "app" {
  name     = var.database_name
  project  = var.gcp_service_account.project_id
  instance = google_sql_database_instance.main.name
}

# Generated once and stored as this instance's password. Alphanumeric-only so
# nothing downstream (env vars, connection-string quoting, shell-based tooling
# an app image might use) needs special escaping.
resource "random_password" "app" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = var.username
  project  = var.gcp_service_account.project_id
  instance = google_sql_database_instance.main.name
  password = random_password.app.result
}
