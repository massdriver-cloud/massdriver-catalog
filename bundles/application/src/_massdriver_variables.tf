// Auto-generated variable declarations from massdriver.yaml
variable "bucket" {
  type = object({
    data = object({
      infrastructure = object({
        bucket_id   = string
        bucket_name = string
      })
      security = optional(object({
        policies = optional(list(object({
          name   = string
          policy = string
        })))
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
variable "bucket_policy" {
  type    = string
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
      security = optional(object({
        policies = optional(list(object({
          name   = string
          policy = string
        })))
      }))
    })
    specs = object({
      database = object({
        engine   = string
        hostname = optional(string)
        port     = optional(number)
        version  = string
      })
      network = optional(object({
        private_ip = optional(string)
        subnet_id  = optional(string)
      }))
    })
  })
  default = null
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
    data = object({
      infrastructure = object({
        cidr       = string
        network_id = string
        subnets = optional(list(object({
          cidr      = string
          subnet_id = string
        })))
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
