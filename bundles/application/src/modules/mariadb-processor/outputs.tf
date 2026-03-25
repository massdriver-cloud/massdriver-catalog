# =============================================================================
# DEMO OUTPUTS — FOR ILLUSTRATIVE PURPOSES ONLY
#
# These outputs exist solely to demonstrate that artifact connection data
# flows correctly between bundles. In production:
#   - NEVER output credentials or sensitive identifiers to Terraform outputs
#   - Use Secrets Manager ARNs and IAM policies for credential access
#   - Use security group IDs for network access (as shown above)
# =============================================================================

output "database_username" {
  value       = var.database.auth.username
  description = "⚠️  DEMO ONLY — Do not output credentials in production. Shown here to illustrate that the MariaDB artifact connection data flows through to the consuming application."
}

output "database_security_group_id" {
  value       = var.database.security_group_id
  description = "⚠️  DEMO ONLY — The security group ID of the MariaDB instance. In production, this is used programmatically (as shown in main.tf) rather than exposed as an output."
}

output "database_secrets_manager_arn" {
  value       = var.database.secrets_manager_arn
  description = "⚠️  DEMO ONLY — The Secrets Manager ARN containing database credentials. Applications should reference this ARN at runtime instead of passing raw passwords through configuration."
}

output "database_hostname" {
  value       = var.database.auth.hostname
  description = "⚠️  DEMO ONLY — Database hostname from the artifact connection."
}

output "security_group_rule_description" {
  value       = "Application '${var.name_prefix}' has been granted MariaDB access on port 3306 via security group rule"
  description = "⚠️  DEMO ONLY — Confirms that the security group binding was established."
}
