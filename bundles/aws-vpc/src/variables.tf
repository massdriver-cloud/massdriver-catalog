variable "aws_authentication" {
  description = "AWS IAM role credentials for provider authentication"
  type = object({
    arn         = string
    external_id = string
  })
  sensitive = true
}

variable "create_nat_gateway" {
  description = "Create a NAT Gateway for private subnet egress. Disable in development to avoid Elastic IP usage."
  type        = bool
  default     = true
}
