terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

provider "google" {
  project     = var.gcp_authentication.project_id
  credentials = jsonencode(var.gcp_authentication)
}

locals {
  project_id  = var.landing_zone.project_id
  name_prefix = var.md_metadata.name_prefix
  region      = var.landing_zone.network.region
  # Workbench instances are zonal resources. Default to the first zone of the region.
  zone = "${local.region}-a"

  # Instance SA is created by THIS bundle — scoped to this specific Workbench instance.
  # See google_service_account.instance below for the design rationale.
  instance_sa_email  = google_service_account.instance.email
  instance_sa_member = "serviceAccount:${google_service_account.instance.email}"

  # Idle shutdown is configured via GCE metadata. The Workbench agent reads
  # "idle-timeout-seconds" and shuts down the instance after the specified
  # number of seconds of kernel inactivity. 0 = never shut down.
  idle_shutdown_seconds = var.idle_shutdown_timeout_minutes * 60

  # Detect whether a GPU is requested.
  has_gpu = var.accelerator_type != null && var.accelerator_type != ""
}

# ─── Instance Service Account ──────────────────────────────────────────────────
# DESIGN DECISION: This bundle always creates a dedicated per-instance service
# account. Workbench instances are intended for data-science exploration with
# scoped, auditable access. Sharing a single SA across multiple Workbench
# instances makes post-hoc access auditing impossible — you can't tell which
# instance accessed a resource. By issuing one SA per instance, every IAM action
# in Cloud Audit Logs is traceable to a specific instance and its owner.
#
# The SA is granted ONLY the roles it needs for resources explicitly connected
# on the Massdriver canvas — no standing access to datasets or buckets it does
# not use. Roles are bound and unbound automatically as connections are added
# or removed.
#
# account_id is derived from name_prefix and capped at 28 chars (GCP limit is 30;
# we reserve 2 chars for future suffix use). The SA lives in the landing zone project.
#
# WARNING: Changing the package name_prefix recreates the SA with a new email.
# Any out-of-band IAM bindings referencing the old SA email are invalidated. Canvas-
# wired bindings are recreated automatically on the next deploy.

resource "google_service_account" "instance" {
  project      = local.project_id
  account_id   = substr(local.name_prefix, 0, 28)
  display_name = "Workbench Instance — ${local.name_prefix}"
  description  = "Runtime identity for Workbench instance ${local.name_prefix}. Managed by Massdriver."
}

# ─── Vertex AI Workbench Instance ─────────────────────────────────────────────
# Uses google_workbench_instance (current Vertex AI Workbench Instances API v2).
# Do NOT use google_notebooks_instance — that resource targets the deprecated
# Notebooks API v1 and is scheduled for removal.
#
# Location is a ZONE, not a region. We derive it from the landing zone region
# by appending "-a" (the first zone in every GCP region). If you need a different
# zone, adjust local.zone above.
#
# Shielded VM (secure boot, vTPM, integrity monitoring) is enabled by default
# as a hardcoded security baseline. Disabling these requires explicit override
# and is not exposed as a param — see compliance notes in README.md.
#
# Public IP is disabled (disable_public_ip = true). Workbench instances reach
# GCP APIs via Private Google Access on the landing zone subnet. No external
# IP is required for normal JupyterLab use — the proxy URL handles browser access.

resource "google_workbench_instance" "main" {
  project  = local.project_id
  name     = local.name_prefix
  location = local.zone

  gce_setup {
    machine_type = var.machine_type

    # ── Shielded VM ──────────────────────────────────────────────────────────
    # Hardcoded security baseline — not configurable. Secure Boot prevents
    # unsigned code from running during startup. vTPM enables measured boot and
    # key attestation. Integrity Monitoring detects tampering of the boot sequence.
    # All three are standard security hygiene for data science VMs.
    shielded_instance_config {
      enable_secure_boot          = true
      enable_vtpm                 = true
      enable_integrity_monitoring = true
    }

    # ── Network ──────────────────────────────────────────────────────────────
    # Place the instance on the landing zone's primary subnet.
    # disable_public_ip prevents an external IP from being assigned — the
    # JupyterLab proxy handles browser access without a public IP.
    disable_public_ip = true

    network_interfaces {
      network  = var.landing_zone.network.network_self_link
      subnet   = var.landing_zone.network.primary_subnet.self_link
      nic_type = "GVNIC"
    }

    # ── Service Account ───────────────────────────────────────────────────────
    # Run as the per-instance SA created above. IAM bindings in iam.tf grant
    # this SA the minimum required roles on any connected upstream data artifact.
    service_accounts {
      email = local.instance_sa_email
    }

    # ── GPU Accelerator ───────────────────────────────────────────────────────
    # Only created when accelerator_type is set. GPUs require N1 machine types.
    # E2 and N2 machine types do not support GPU attachment.
    dynamic "accelerator_configs" {
      for_each = local.has_gpu ? [1] : []
      content {
        type       = var.accelerator_type
        core_count = var.accelerator_count
      }
    }

    # ── Boot Disk ─────────────────────────────────────────────────────────────
    boot_disk {
      disk_size_gb = var.boot_disk_size_gb
      disk_type    = "PD_SSD"
    }

    # ── Metadata ──────────────────────────────────────────────────────────────
    # idle-timeout-seconds: Workbench agent shuts down the instance after this
    # many seconds of kernel inactivity. 0 = never (not recommended — continuous billing).
    # serial-port-logging-enable: disabled by default; enable only for deep debugging.
    metadata = merge(
      {
        "serial-port-logging-enable" = "false"
      },
      local.idle_shutdown_seconds > 0 ? {
        "idle-timeout-seconds" = tostring(local.idle_shutdown_seconds)
      } : {}
    )
  }

  labels = var.md_metadata.default_tags

  # Google adds auto-managed keys to metadata post-creation (for example
  # enable-jupyterlab4, proxy-mode). Terraform sees those as drift and wants to
  # prune them, which triggers a gce_setup update. The Workbench API then
  # rejects the apply because updates to gce_setup require the instance to be
  # stopped first — even when no restricted field (machine_type, shielded
  # config, etc.) is actually changing. Ignoring metadata drift keeps
  # redeploys no-op when only the user-managed keys are stable.
  lifecycle {
    ignore_changes = [
      gce_setup[0].metadata,
    ]
  }
}
