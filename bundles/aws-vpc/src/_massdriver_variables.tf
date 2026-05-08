// Auto-generated variable declarations from massdriver.yaml
variable "availability_zone_count" {
  type    = number
  default = 3
}
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "enable_dns_hostnames" {
  type    = bool
  default = true
}
variable "enable_flow_logs" {
  type    = bool
  default = true
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
variable "nat_gateway_mode" {
  type    = string
  default = "single"
}
