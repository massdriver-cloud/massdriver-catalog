// Auto-generated variable declarations from massdriver.yaml
variable "bucket" {
  type = object({
    infrastructure = object({
      bucket_id   = string
      bucket_name = string
      endpoint    = optional(string)
    })
    policies = list(object({
      id   = string
      name = string
    }))
  })
  default = null
}
variable "bucket_policy" {
  type    = string
  default = null
}
variable "database" {
  type = object({
    connection = object({
      database = string
      hostname = string
      password = string
      port     = number
      username = string
    })
    infrastructure = object({
      database_id = string
    })
    policies = list(object({
      id   = string
      name = string
    }))
  })
}
variable "database_policy" {
  type    = string
  default = null
}
variable "domain_name" {
  type = string
}
variable "image" {
  type = string
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
variable "network" {
  type = object({
    infrastructure = object({
      cidr       = string
      network_id = string
    })
    subnets = list(object({
      cidr      = string
      subnet_id = string
      type      = optional(string)
    }))
  })
}
variable "port" {
  type    = number
  default = 8080
}
variable "replicas" {
  type = number
}
