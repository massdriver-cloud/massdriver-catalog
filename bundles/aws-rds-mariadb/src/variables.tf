variable "aws_authentication" {
  description = "AWS IAM role credentials for provider authentication"
  type = object({
    arn         = string
    external_id = optional(string)
  })
  sensitive = true
}
