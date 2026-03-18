variable "region" {
  type        = string
  description = "AWS region where the DynamoDB table will be created."
}

variable "table_name" {
  type        = string
  description = "Name of the DynamoDB table."
}

variable "hash_key" {
  type        = string
  description = "Attribute name for the partition key."
}

variable "hash_key_type" {
  type        = string
  description = "Data type for the partition key: S (String), N (Number), or B (Binary)."
  default     = "S"
}

variable "range_key" {
  type        = string
  description = "Optional attribute name for the sort key."
  default     = null
}

variable "range_key_type" {
  type        = string
  description = "Data type for the sort key: S (String), N (Number), or B (Binary)."
  default     = "S"
}

variable "billing_mode" {
  type        = string
  description = "PAY_PER_REQUEST or PROVISIONED billing mode."
  default     = "PAY_PER_REQUEST"
}

variable "read_capacity" {
  type        = number
  description = "Provisioned read capacity units (PROVISIONED mode only)."
  default     = 5
}

variable "write_capacity" {
  type        = number
  description = "Provisioned write capacity units (PROVISIONED mode only)."
  default     = 5
}

variable "enable_streams" {
  type        = bool
  description = "Whether to enable DynamoDB Streams."
  default     = false
}

variable "stream_view_type" {
  type        = string
  description = "What data is written to the stream when enabled."
  default     = "NEW_AND_OLD_IMAGES"
}

variable "aws_authentication" {
  type = object({
    arn         = string
    external_id = optional(string)
  })
  description = "AWS IAM role credentials."
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
  description = "Massdriver metadata injected at deploy time."
}
