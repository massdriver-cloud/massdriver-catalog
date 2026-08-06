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

variable "bigquery_dataset" {
  type = object({
    project_id        = string
    dataset_id        = string
    dataset_full_name = string
    location          = string
    friendly_name     = optional(string)
  })
}

# Optional — only present when a Pub/Sub topic is wired on the canvas.
variable "pubsub_topic" {
  description = "Pub/Sub topic artifact. When wired, a BigQuery subscription is created to deliver messages into this table."
  type = object({
    project_id     = string
    topic_name     = string
    topic_id       = string
    dlq_topic_id   = optional(string)
    dlq_topic_name = optional(string)
  })
  default = null
}

variable "table_id" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "schema_mode" {
  type    = string
  default = "pubsub_default"
}

variable "schema_json" {
  type    = string
  default = null
}

variable "bigquery_subscription" {
  description = "Settings for the Pub/Sub BigQuery subscription. Consumed only when pubsub_topic is non-null."
  type = object({
    use_topic_schema     = optional(bool, false)
    write_metadata       = optional(bool, true)
    drop_unknown_fields  = optional(bool, false)
    ack_deadline_seconds = optional(number, 60)
  })
  default = {}
}
