// Auto-generated variable declarations from massdriver.yaml
variable "availability" {
  type = object({
    high_availability = optional(bool)
  })
  default = null
}
variable "backup" {
  type = object({
    enabled                = optional(bool)
    point_in_time_recovery = optional(bool)
  })
  default = null
}
variable "database_name" {
  type = string
}
variable "db_version" {
  type = string
}
variable "disk_size" {
  type    = number
  default = 10
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
variable "region" {
  type = string
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
}
variable "tier" {
  type    = string
  default = "db-f1-micro"
}
variable "username" {
  type = string
}
