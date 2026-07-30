resource "massdriver_resource" "email" {
  field = "email"
  name  = "SES Sending Credentials (${var.md_metadata.name_prefix})"
  resource = jsonencode({
    domain            = var.domain
    region            = var.region
    configuration_set = aws_ses_configuration_set.main.name
    smtp = {
      host     = "email-smtp.${var.region}.amazonaws.com"
      port     = 587
      username = aws_iam_access_key.smtp.id
      password = aws_iam_access_key.smtp.ses_smtp_password_v4
    }
  })
}
