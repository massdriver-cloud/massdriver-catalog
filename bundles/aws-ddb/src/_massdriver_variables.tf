// Auto-generated variable declarations from massdriver.yaml
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "backup" {
  type = object({
    deletion_protection    = optional(bool)
    point_in_time_recovery = optional(bool)
  })
  default = null
}
variable "billing" {
  type = object({
    mode = string
    provisioned = optional(object({
      read_capacity  = optional(number)
      write_capacity = optional(number)
    }))
  })
}
variable "indexes" {
  type = object({
    global = optional(list(object({
      hash_key = object({
        name = string
        type = string
      })
      name               = string
      non_key_attributes = optional(list(string))
      projection_type    = optional(string)
      range_key = optional(object({
        name = optional(string)
        type = optional(string)
      }))
    })))
    local = optional(list(object({
      name               = string
      non_key_attributes = optional(list(string))
      projection_type    = optional(string)
      range_key = object({
        name = string
        type = string
      })
    })))
  })
  default = null
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
variable "stream" {
  type = object({
    enabled   = optional(bool)
    view_type = optional(string)
  })
  default = null
}
variable "table" {
  type = object({
    hash_key = object({
      name = string
      type = string
    })
    name = string
    range_key = optional(object({
      name = optional(string)
      type = optional(string)
    }))
  })
}
