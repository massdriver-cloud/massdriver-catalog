// Auto-generated variable declarations from massdriver.yaml
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
variable "subnets" {
  type = list(object({
    cidr = string
    name = string
  }))
  default = [{"cidr":"10.0.1.0/24","name":"subnet-a"},{"cidr":"10.0.2.0/24","name":"subnet-b"}]
}
