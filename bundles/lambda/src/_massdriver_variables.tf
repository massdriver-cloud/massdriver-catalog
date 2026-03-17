// Auto-generated variable declarations from massdriver.yaml
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

// Auto-generated variable declarations from massdriver.yaml - params
variable "region" {
  type = string
}

variable "lambda_memory_mb" {
  type = number
}

variable "lambda_timeout_seconds" {
  type = number
}

variable "dynamodb_policy" {
  type = string
}

variable "log_retention_days" {
  type = number
}

// Auto-generated variable declarations from massdriver.yaml - connections
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = string
  })
}

variable "dynamodb_table" {
  type = object({
    arn        = string
    name       = string
    region     = string
    stream_arn = string
  })
}
