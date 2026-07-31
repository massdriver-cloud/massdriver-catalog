# Email

Provisions an SES domain identity, DKIM signing, a configuration set, and SMTP sending credentials for transactional email (password resets, receipts, notifications). Emits an `email-credentials` resource with the SMTP host, port, username, and password.

## Why SMTP rather than the SES API

The credentials work with any standard mail library (`nodemailer`, `smtplib`, JavaMail). Because the integration is plain SMTP rather than a provider-specific send API, switching providers later means changing a hostname and credentials, not application code.

## One manual step after deploy

Domain verification requires proof of DNS ownership, which Terraform cannot provide unless it also manages the DNS zone. After deploying, add the DKIM CNAME records listed in the operator runbook at your DNS provider. Sending is blocked until verification completes.

## Operational notes

- New AWS accounts start in the SES sandbox and can only send to verified addresses until production access is requested.
- `src/main.tf` provisions the domain identity, DKIM, configuration set, and IAM-based SMTP credentials.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
