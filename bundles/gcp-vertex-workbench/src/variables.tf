variable "md_metadata" {
  type = object({
    name_prefix  = string
    default_tags = optional(map(string), {})
  })
}

variable "gcp_authentication" {
  type = object({
    type                        = string
    project_id                  = string
    private_key_id              = string
    private_key                 = string
    client_email                = string
    client_id                   = string
    auth_uri                    = string
    token_uri                   = string
    auth_provider_x509_cert_url = string
    client_x509_cert_url        = string
  })
  sensitive = true
}

variable "landing_zone" {
  type = object({
    project_id = string
    network = object({
      network_name      = string
      network_self_link = string
      region            = string
      primary_subnet = object({
        name      = string
        cidr      = string
        self_link = string
      })
    })
    enabled_apis = list(string)
    budget = object({
      enabled            = bool
      budget_name        = optional(string)
      billing_account_id = optional(string)
      amount_usd         = optional(number)
    })
  })
}

# ─── Optional upstream artifact connections ────────────────────────────────────
# These variables are null when the connection is not wired on the canvas.
# Massdriver passes optional connections as a plain object or null — NOT a list.
# iam.tf uses count = var.<name> != null ? 1 : 0 to conditionally create IAM
# bindings, and references fields directly (e.g., var.bigquery_dataset.dataset_id).

variable "bigquery_dataset" {
  description = "Optional BigQuery dataset connection. When provided, the instance SA is granted roles/bigquery.dataViewer (read-only) on the dataset."
  type = object({
    project_id        = string
    dataset_id        = string
    dataset_full_name = string
    location          = string
    friendly_name     = optional(string)
  })
  default = null
}

# ─── Instance params ───────────────────────────────────────────────────────────

variable "machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "boot_disk_size_gb" {
  type    = number
  default = 150
}

variable "idle_shutdown_timeout_minutes" {
  type    = number
  default = 180
}

variable "accelerator_type" {
  type    = string
  default = null
}

variable "accelerator_count" {
  type    = number
  default = 1
}
