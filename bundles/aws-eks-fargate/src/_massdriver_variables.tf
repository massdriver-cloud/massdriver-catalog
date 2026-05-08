// Auto-generated variable declarations from massdriver.yaml
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "cluster_name" {
  type = string
}
variable "endpoint_access" {
  type    = string
  default = "public-and-private"
}
variable "fargate_namespaces" {
  type    = list(string)
  default = ["default", "kube-system"]
}
variable "kubernetes_version" {
  type    = string
  default = "1.30"
}
variable "log_types" {
  type    = list(string)
  default = ["audit", "authenticator"]
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
variable "public_access_cidrs" {
  type    = list(string)
  default = []
}
variable "secrets_encryption_enabled" {
  type    = bool
  default = true
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
