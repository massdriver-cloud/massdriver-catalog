# =============================================================================
# MariaDB Processor
#
# This submodule demonstrates how Massdriver artifact connections encode
# security and compliance metadata — enabling programmatic, reproducible,
# and auditable infrastructure wiring between bundles.
#
# Key concepts illustrated:
#   1. Network access via security group binding (not CIDR allowlists)
#   2. Credential access via Secrets Manager ARN (not raw passwords)
#   3. Policy-based access selection via $md.enum
# =============================================================================

# -----------------------------------------------------------------------------
# Network Access: Security Group Binding
#
# Instead of hard-coding CIDR blocks or opening wide network access, the
# MariaDB artifact exposes its security_group_id. The consuming application
# creates a targeted ingress rule — granting only this specific application
# access to the database on port 3306.
#
# This is:
#   - Programmatic: no manual console clicks
#   - Reproducible: identical across environments
#   - Auditable: every connection is an explicit Terraform resource
# -----------------------------------------------------------------------------

resource "aws_security_group_rule" "allow_app_to_mariadb" {
  type                     = "ingress"
  description              = "Allow ${var.name_prefix} application to connect to MariaDB"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = var.application_security_group_id
  security_group_id        = var.database.security_group_id
}

# -----------------------------------------------------------------------------
# Credential Access: Secrets Manager Reference
#
# The artifact provides a secrets_manager_arn instead of requiring raw
# passwords to flow through configuration. Applications should:
#   1. Reference the secret ARN in their environment/config
#   2. Use IAM roles to grant read access to the secret
#   3. Retrieve credentials at runtime via the Secrets Manager API
#
# This means passwords never appear in Terraform state, environment variables,
# or application config files — only the ARN reference does.
# -----------------------------------------------------------------------------

# In a real application, you would pass this ARN as an environment variable:
#
#   module "app" {
#     source = "github.com/massdriver-cloud/terraform-massdriver-application"
#     ...
#     env = {
#       DB_SECRET_ARN = var.database.secrets_manager_arn
#       DB_HOST       = var.database.auth.hostname
#       DB_PORT       = tostring(var.database.auth.port)
#       DB_NAME       = var.database.auth.database
#     }
#   }
#
# The application code then calls Secrets Manager at startup to retrieve
# the username and password — keeping credentials out of the deploy pipeline.
