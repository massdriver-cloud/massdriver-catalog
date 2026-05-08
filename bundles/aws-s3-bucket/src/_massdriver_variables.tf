// Auto-generated variable declarations from massdriver.yaml
variable "allowed_mime_types" {
  type    = list(string)
  default = ["image/jpeg", "image/png", "image/webp", "image/gif", "video/mp4"]
}
variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
}
variable "block_public_access" {
  type    = bool
  default = true
}
variable "bucket_name_prefix" {
  type = string
}
variable "cors_origins" {
  type = list(string)
}
variable "enable_access_logs" {
  type    = bool
  default = false
}
variable "enable_intelligent_tiering" {
  type    = bool
  default = false
}
variable "encryption" {
  type    = string
  default = "sse-kms"
}
variable "lifecycle_archive_after_days" {
  type    = number
  default = 0
}
variable "lifecycle_expire_after_days" {
  type    = number
  default = 0
}
variable "max_upload_size_mb" {
  type    = number
  default = 100
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
variable "object_ownership" {
  type    = string
  default = "bucket-owner-enforced"
}
variable "presigned_url_expiration_seconds" {
  type    = number
  default = 900
}
variable "versioning" {
  type    = string
  default = "enabled"
}
