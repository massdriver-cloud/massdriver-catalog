// Auto-generated variable declarations from massdriver.yaml
variable "container" {
  type = object({
    cpu = optional(string)
    env = optional(list(object({
      name  = string
      value = string
    })))
    image  = string
    memory = optional(string)
    port   = optional(number)
  })
}
variable "database" {
  type = object({
    auth = object({
      database = string
      hostname = string
      password = string
      port     = number
      username = string
    })
    id = string
    policies = list(object({
      id   = string
      name = string
    }))
    version = optional(string)
  })
  default = null
}
variable "gcp_authentication" {
  type = object({
    auth_provider_x509_cert_url = string
    auth_uri                    = string
    client_email                = string
    client_id                   = string
    client_x509_cert_url        = string
    private_key                 = string
    private_key_id              = string
    project_id                  = string
    token_uri                   = string
    type                        = string
  })
}
variable "ingress" {
  type    = string
  default = "all"
}
variable "md_metadata" {
  type = object({
    default_tags = object({
      managed-by  = string
      md-manifest = string
      md-package  = string
      md-project  = string
      md-target   = string
    })
    deployment = object({
      id = string
    })
    name_prefix = string
    observability = object({
      alarm_webhook_url = string
    })
    package = object({
      created_at             = string
      deployment_enqueued_at = string
      previous_status        = string
      updated_at             = string
    })
    target = object({
      contact_email = string
    })
  })
}
variable "region" {
  type = string
}
variable "scaling" {
  type = object({
    max_instances = optional(number)
    min_instances = optional(number)
  })
  default = null
}
variable "subnetwork" {
  type = object({
    cidr                        = string
    network_id                  = string
    private_services_connection = optional(string)
    project_id                  = string
    region                      = string
    subnet_id                   = string
    vpc_access_connector        = optional(string)
  })
  default = null
}
