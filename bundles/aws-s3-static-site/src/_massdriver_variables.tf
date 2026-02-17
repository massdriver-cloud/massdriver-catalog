// Auto-generated variable declarations from massdriver.yaml
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "error_page" {
  type    = string
  default = "\u003c!DOCTYPE html\u003e\n\u003chtml\u003e\n\u003chead\u003e\u003ctitle\u003ePage Not Found\u003c/title\u003e\u003c/head\u003e\n\u003cbody\u003e\u003ch1\u003e404 - Page Not Found\u003c/h1\u003e\u003c/body\u003e\n\u003c/html\u003e\n"
}
variable "html_content" {
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
variable "site_name" {
  type = string
}
// Auto-generated variable declarations from massdriver.yaml
variable "enable_versioning" {
  type    = bool
  default = false
}
