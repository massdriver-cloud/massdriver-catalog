// Auto-generated variable declarations from massdriver.yaml
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "backup_retention_period" {
  type    = number
  default = 7
}
variable "backup_window" {
  type = string
}
variable "database_name" {
  type = string
}
variable "db_version" {
  type = string
}
variable "instance_class" {
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
variable "subnet_ids" {
  type = list(string)
}
variable "username" {
  type = string
}
variable "vpc" {
  type = object({
    arn    = string
    cidr   = string
    id     = string
    region = string
    subnets = list(object({
      arn               = string
      availability_zone = string
      cidr              = string
      id                = string
      name              = optional(string)
      type              = string
    }))
  })
}
// Auto-generated variable declarations from massdriver.yaml
variable "deletion_protection" {
  type    = bool
  default = true
}
