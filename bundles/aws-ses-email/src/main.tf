locals {
  name_prefix = var.md_metadata.name_prefix
}

resource "aws_ses_domain_identity" "main" {
  domain = var.domain
}

# DKIM signing — the three CNAME records this produces are what actually
# gets sending "verified" once they're published in DNS.
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_ses_configuration_set" "main" {
  name = "${local.name_prefix}-config"
}

resource "aws_iam_user" "smtp" {
  name = "${local.name_prefix}-ses-smtp"
}

resource "aws_iam_access_key" "smtp" {
  user = aws_iam_user.smtp.name
}

resource "aws_iam_user_policy" "smtp_send" {
  name = "${local.name_prefix}-ses-send"
  user = aws_iam_user.smtp.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendRawEmail", "ses:SendEmail"]
      Resource = aws_ses_domain_identity.main.arn
    }]
  })
}

# SES SMTP passwords aren't the raw IAM secret key — they're derived from it
# via a fixed HMAC-SHA256 chain. No Terraform-native function does this, so
# it's computed by a small local script instead.
data "external" "smtp_password" {
  program = ["python3", "${path.module}/scripts/ses_smtp_password.py"]
  query = {
    secret_access_key = aws_iam_access_key.smtp.secret
    region            = var.network.region
  }
}
