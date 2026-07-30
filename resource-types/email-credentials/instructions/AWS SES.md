# Importing existing SES sending credentials

Use this when you already have a verified SES domain identity and SMTP credentials, instead of provisioning them with the `aws-ses-email` bundle.

## Where to find each field

1. Open the **SES console** → **Verified identities** → your domain.
   - `domain`: the verified domain name.
   - `region`: shown in the top-right of the console (SES sending is region-specific).
2. Go to **SMTP settings** in the left nav.
   - `smtp.host`: the "SMTP endpoint" shown for your region.
   - `smtp.port`: `587` (STARTTLS) is the usual choice.
   - Click **Create SMTP credentials** if you don't already have a set — this generates an IAM user with SES-send-only permissions and converts its keys to SMTP username/password.
   - `smtp.username` / `smtp.password`: the generated SMTP credentials (the password is only shown once at creation — store it in a secret manager if you didn't already).
3. If you use a configuration set for delivery/bounce/complaint tracking: **Configuration sets** → copy its name into `configuration_set`.

## Notes

- SMTP credentials are used deliberately over the native SES API so the app's outbound-mail code isn't locked to AWS — the same SMTP integration works against any other provider's SMTP endpoint if you migrate later.
