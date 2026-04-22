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

variable "dataset_id" {
  type = string
}

variable "friendly_name" {
  type    = string
  default = null
}

variable "description" {
  type    = string
  default = null
}

variable "location" {
  type    = string
  default = "US"
}

variable "default_table_expiration_days" {
  type    = number
  default = 0
}

variable "delete_protection" {
  type    = bool
  default = false
}

# Optional — only present when a Pub/Sub topic is wired on the canvas.
variable "pubsub_topic" {
  description = "Pub/Sub topic artifact. When wired, a BigQuery subscription is created to deliver messages into this dataset."
  type = object({
    project_id     = string
    topic_name     = string
    topic_id       = string
    dlq_topic_id   = optional(string)
    dlq_topic_name = optional(string)
  })
  default = null
}

variable "bigquery_subscription" {
  description = "Settings for the Pub/Sub BigQuery subscription. Consumed only when pubsub_topic is non-null."
  type = object({
    table_name           = optional(string)
    use_topic_schema     = optional(bool, false)
    write_metadata       = optional(bool, false)
    drop_unknown_fields  = optional(bool, false)
    ack_deadline_seconds = optional(number, 60)
  })
  default = {}
}
