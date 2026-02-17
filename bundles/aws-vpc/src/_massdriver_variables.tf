// Auto-generated variable declarations from massdriver.yaml
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "cidr" {
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
variable "region" {
  type = string
}
variable "subnets" {
  type = list(object({
    availability_zone = string
    cidr              = string
    name              = string
    type              = string
  }))
  default = [{ "availability_zone" : "a", "cidr" : "10.0.1.0/24", "name" : "public-a", "type" : "public" }, { "availability_zone" : "a", "cidr" : "10.0.10.0/24", "name" : "private-a", "type" : "private" }]
}
// Auto-generated variable declarations from massdriver.yaml
variable "enable_s3_endpoint" {
  type    = bool
  default = false
}
// Auto-generated variable declarations from massdriver.yaml
variable "enable_nat_gateway" {
  type    = bool
  default = false
}
