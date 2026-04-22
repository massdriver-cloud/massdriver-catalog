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
  project_id  = var.bigquery_dataset.project_id
  dataset_id  = var.bigquery_dataset.dataset_id
  name_prefix = var.md_metadata.name_prefix

  # Subscription name derived from the bundle name prefix for uniqueness.
  subscription_name = "${local.name_prefix}-bq"

  # Pub/Sub-compatible schema — used when schema_mode = "pubsub_default".
  # Includes the five standard columns that BigQuery subscription write_metadata
  # populates: subscription_name, message_id, publish_time, data, attributes.
  pubsub_default_schema = jsonencode([
    {
      name = "subscription_name"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "message_id"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "publish_time"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    },
    {
      name = "data"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "attributes"
      type = "JSON"
      mode = "NULLABLE"
    },
  ])

  # Resolved schema — prefer custom_schema when provided, otherwise use pubsub default.
  resolved_schema = (
    var.schema_mode == "custom_schema" && var.schema_json != null
    ? var.schema_json
    : local.pubsub_default_schema
  )
}

# ─── BigQuery Table ────────────────────────────────────────────────────────────

resource "google_bigquery_table" "main" {
  project    = local.project_id
  dataset_id = local.dataset_id
  table_id   = var.table_id

  description = var.description != null ? var.description : null

  # When deletion_protection = true, Terraform will refuse to destroy this table
  # until the flag is first set to false and re-applied (a two-step destroy).
  deletion_protection = var.deletion_protection

  schema = local.resolved_schema

  labels = var.md_metadata.default_tags
}
