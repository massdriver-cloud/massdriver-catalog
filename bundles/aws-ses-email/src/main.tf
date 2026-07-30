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

  delivery_options {
    tls_policy = "Require"
  }
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
