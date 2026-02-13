// Auto-generated variable declarations from massdriver.yaml
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "custom_model_s3_uri" {
  type    = string
  default = ""
}
variable "endpoint_name" {
  type = string
}
variable "initial_instance_count" {
  type    = number
  default = 1
}
variable "instance_type" {
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
variable "model_source" {
  type = string
}
variable "sagemaker_domain" {
  type = object({
    default_bucket     = optional(string)
    domain_arn         = string
    domain_id          = string
    execution_role_arn = string
    region             = string
    security_group_id  = optional(string)
    studio_url         = optional(string)
    subnet_ids         = optional(list(string))
    vpc_id             = optional(string)
  })
}
