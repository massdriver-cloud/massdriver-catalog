// Auto-generated variable declarations from massdriver.yaml
variable "cidr" {
  type = string
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
variable "private_services_cidr" {
  type    = string
  default = "10.100.0.0/16"
}
variable "region" {
  type = string
}
