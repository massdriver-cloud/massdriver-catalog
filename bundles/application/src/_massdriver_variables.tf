// Auto-generated variable declarations from massdriver.yaml
variable "bucket" {
  type = object({
    data = object({
      infrastructure = object({
        bucket_name = string
        id          = string
      })
      security = optional(object({
        iam = optional(object({
          read  = optional(object({}))
          write = optional(object({}))
        }))
      }))
    })
    specs = object({
      storage = object({
        type = string
      })
    })
  })
  default = null
}
variable "database" {
  type = object({
    data = object({
      authentication = object({
        database = optional(string)
        hostname = string
        password = string
        port     = number
        username = string
      })
      infrastructure = object({
        id = optional(string)
      })
    })
    specs = object({
      database = object({
        engine  = string
        version = string
      })
    })
  })
  default = null
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
    data = object({
      infrastructure = object({
        cidr       = string
        network_id = string
        subnets    = optional(list(string))
      })
    })
    specs = object({
      network = object({
        cidr = string
      })
    })
  })
}
variable "port" {
  type    = number
  default = 8080
}
variable "replicas" {
  type = number
}
