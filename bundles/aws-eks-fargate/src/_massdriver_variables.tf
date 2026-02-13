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
variable "endpoint_private_access" {
  type    = bool
  default = true
}
variable "endpoint_public_access" {
  type    = bool
  default = true
}
variable "fargate_namespaces" {
  type    = list(string)
  default = []
}
variable "kubernetes_version" {
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
variable "vpc" {
  type = object({
    arn                = string
    cidr               = string
    id                 = string
    region             = string
    s3_vpc_endpoint_id = optional(string)
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
