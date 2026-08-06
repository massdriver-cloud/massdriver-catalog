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

variable "bigquery_dataset" {
  description = "Optional BigQuery dataset destination. Must be wired when the sink routes to BigQuery."
  type = object({
    project_id        = string
    dataset_id        = string
    dataset_full_name = string
    location          = string
    friendly_name     = optional(string)
  })
  default = null
}

variable "storage_bucket" {
  description = "Optional GCS bucket destination. Must be wired when the sink routes to GCS."
  type = object({
    project_id       = string
    bucket_name      = string
    bucket_url       = string
    bucket_self_link = string
    location         = string
    storage_class    = string
  })
  default = null
}

variable "filter" {
  description = "Cloud Logging query filter. Empty string means include all logs."
  type        = string
  default     = ""
}

variable "use_partitioned_tables" {
  description = "Write to date-partitioned BigQuery tables. Ignored for GCS destinations."
  type        = bool
  default     = true
}

variable "exclusions" {
  description = "Log exclusion rules applied after the sink filter."
  type = list(object({
    name        = string
    filter      = string
    description = optional(string)
    disabled    = optional(bool, false)
  }))
  default = []
}
