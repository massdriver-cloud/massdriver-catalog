# Email

Lets your app send real email — password resets, receipts, notifications — from a domain you actually own, instead of a throwaway address that lands in spam.

## What you get

- A domain identity, ready for verification.
- SMTP credentials your app can drop straight into any standard mail library — Node's `nodemailer`, Python's `smtplib`, whatever you're using. This is deliberately SMTP, not a proprietary send API, so if you switch providers later, you change a hostname and keep your app's mail code exactly as it is.

## One manual step after deploy

Verifying a domain needs proof you own its DNS — something Terraform can't do on your behalf without you owning that DNS zone in this same account. After deploying, check the operator runbook for the DKIM CNAME records SES generated, and add them at your DNS provider. Sending won't work until that's done, and there's no way around it — this isn't a bug, it's how domain verification works everywhere.

## Customize it

1. Edit `massdriver.yaml` if you need more than a single domain per instance.
2. `src/main.tf` provisions the real domain identity, DKIM, a configuration set, and IAM-based SMTP credentials.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
