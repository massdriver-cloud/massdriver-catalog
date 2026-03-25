variable "name_prefix" {
  type        = string
  description = "Resource naming prefix from Massdriver metadata"
}

variable "database" {
  type = object({
    auth = object({
      database = string
      hostname = string
      password = string
      port     = number
      username = string
    })
    id                  = string
    security_group_id   = string
    secrets_manager_arn = string
    policies = list(object({
      id   = string
      name = string
    }))
  })
  description = "MariaDB connection artifact from Massdriver"
}

variable "application_security_group_id" {
  type        = string
  description = "Security group ID of the consuming application. An ingress rule will be added to the database security group to allow this application to connect."
}
