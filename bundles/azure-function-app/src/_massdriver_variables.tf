// Auto-generated variable declarations from massdriver.yaml
variable "azure_authentication" {
  type = object({
    client_id       = string
    client_secret   = string
    subscription_id = string
    tenant_id       = string
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
variable "storage" {
  type = object({
    data = object({
      connection_string     = string
      container_name        = string
      primary_access_key    = optional(string)
      primary_blob_endpoint = optional(string)
      resource_group_name   = string
    })
    endpoint = string
    id       = string
    name     = string
    policies = list(object({
      id   = string
      name = string
    }))
  })
}
variable "storage_policy" {
  type = string
}
// Auto-generated variable declarations from massdriver.yaml
variable "image" {
  type    = string
  default = null
}
