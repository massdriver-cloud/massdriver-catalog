// Auto-generated variable declarations from massdriver.yaml
variable "availability" {
  type = object({
    multi_az = optional(bool)
  })
  default = null
}
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "backup" {
  type = object({
    retention_days = optional(number)
  })
  default = null
}
variable "capacity" {
  type = object({
    max_acu = optional(number)
    min_acu = optional(number)
  })
  default = null
}
variable "database_name" {
  type = string
}
variable "engine_version" {
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
variable "region" {
  type = string
}
variable "username" {
  type = string
}
variable "vpc" {
  type = object({
    arn  = optional(string)
    cidr = string
    id   = string
    private_subnets = list(object({
      arn               = optional(string)
      availability_zone = optional(string)
      cidr              = optional(string)
      id                = optional(string)
    }))
    public_subnets = list(object({
      arn               = optional(string)
      availability_zone = optional(string)
      cidr              = optional(string)
      id                = optional(string)
    }))
    region = string
  })
}
