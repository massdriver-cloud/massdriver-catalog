// Auto-generated variable declarations from massdriver.yaml
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
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
variable "ingress" {
  type    = string
  default = "public"
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
    max_concurrency = optional(number)
    max_instances   = optional(number)
    min_instances   = optional(number)
  })
  default = null
}
variable "vpc" {
  type = object({
    cidr = string
    id   = string
    private_subnets = list(object({
      availability_zone = string
      cidr              = string
      id                = string
    }))
    public_subnets = list(object({
      availability_zone = string
      cidr              = string
      id                = string
    }))
    region = string
    vpc_id = string
  })
  default = null
}
