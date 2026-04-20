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
    workload_identity = object({
      service_account_email = string
      service_account_id    = string
      service_account_name  = string
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
# bindings, and references fields directly (e.g., var.pubsub_topic.topic_name).

variable "pubsub_topic" {
  description = "Optional Pub/Sub topic connection. When provided, the workload SA is granted roles/pubsub.publisher on the topic."
  type = object({
    project_id     = string
    topic_name     = string
    topic_id       = string
    dlq_topic_name = optional(string)
    dlq_topic_id   = optional(string)
  })
  default = null
}

variable "bigquery_dataset" {
  description = "Optional BigQuery dataset connection. When provided, the workload SA is granted roles/bigquery.dataEditor on the dataset."
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
  description = "Optional GCS bucket connection. When provided, the workload SA is granted roles/storage.objectUser on the bucket."
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

# ─── Service params ────────────────────────────────────────────────────────────

variable "image" {
  type    = string
  default = "gcr.io/cloudrun/hello"
}

variable "port" {
  type    = number
  default = 8080
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 100
}

variable "ingress" {
  type    = string
  default = "internal"
}

variable "allow_unauthenticated" {
  type    = bool
  default = false
}
