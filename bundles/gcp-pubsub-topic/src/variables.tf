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

variable "message_retention_duration" {
  type    = number
  default = 604800
}

variable "message_ordering_enabled" {
  type    = bool
  default = false
}

variable "dlq" {
  type = object({
    enabled                = bool
    max_delivery_attempts  = optional(number)
    dlq_retention_duration = optional(number)
  })
}
