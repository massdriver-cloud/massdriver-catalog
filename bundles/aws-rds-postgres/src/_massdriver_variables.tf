// Auto-generated variable declarations from massdriver.yaml
variable "allocated_storage_gb" {
  type    = number
  default = 20
}
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "backup_retention_days" {
  type    = number
  default = 7
}
variable "database_name" {
  type    = string
  default = "appdb"
}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "engine_version" {
  type    = string
  default = "16"
}
variable "iam_database_auth" {
  type    = bool
  default = true
}
variable "instance_class" {
  type    = string
  default = "db.t4g.medium"
}
variable "master_password" {
  type    = string
  default = null
}
variable "max_allocated_storage_gb" {
  type    = number
  default = 100
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
variable "multi_az" {
  type    = bool
  default = false
}
variable "performance_insights_enabled" {
  type    = bool
  default = false
}
variable "read_replica_count" {
  type    = number
  default = 0
}
variable "storage_encrypted" {
  type    = bool
  default = true
}
variable "username" {
  type    = string
  default = "appadmin"
}
variable "vpc" {
  type = object({
    id         = string
    arn        = optional(string)
    cidr       = string
    region     = string
    account_id = optional(string)
    subnets = list(object({
      id                = string
      cidr              = string
      availability_zone = string
      type              = string
    }))
    security_group_ids = optional(object({
      default   = optional(string)
      endpoints = optional(string)
    }))
  })
}
