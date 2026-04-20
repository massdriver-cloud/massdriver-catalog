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

variable "network" {
  type = object({
    project_id        = string
    network_name      = string
    network_self_link = string
    region            = string
    primary_subnet = object({
      name      = string
      cidr      = string
      self_link = string
    })
  })
}

variable "service_account_name" {
  type = string
}

variable "enabled_apis" {
  type = list(string)
}

variable "budget" {
  type = object({
    enabled               = bool
    billing_account_id    = optional(string)
    amount                = optional(number)
    threshold_percentages = optional(list(number))
    notification_emails   = optional(list(string), [])
  })
}
