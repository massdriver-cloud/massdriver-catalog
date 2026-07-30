---
templating: mustache
---

# Email Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Domain | `{{artifacts.email.domain}}` |
| SMTP host | `{{artifacts.email.smtp.host}}` |
| SMTP port | `{{artifacts.email.smtp.port}}` |
| Configuration set | `{{artifacts.email.configuration_set}}` |

---

## First-deploy setup: verify the domain

SES can't send from `{{artifacts.email.domain}}` until DNS proves you own it.

```bash
aws ses get-identity-verification-attributes --identities {{artifacts.email.domain}}
aws ses get-identity-dkim-attributes --identities {{artifacts.email.domain}}
```

Take the three DKIM tokens from that second command and add them at your DNS provider as:

```
<token>._domainkey.{{artifacts.email.domain}}.  CNAME  <token>.dkim.amazonses.com.
```

Verification usually completes within a few minutes to a few hours after the records propagate. Until then, `SendEmail`/`SendRawEmail` calls will fail.

{{#params.domain}}
### New AWS accounts start in the SES sandbox

You can only send to verified addresses until you request production access. Check:
```bash
aws sesv2 get-account | grep -A2 ProductionAccessEnabled
```
{{/params.domain}}

---

## Active alarms — what they mean

### Bounce or complaint rate climbing

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/SES --metric-name Reputation.BounceRate \
  --start-time $(date -u -d '1 day ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 3600 --statistics Maximum
```

AWS suspends sending if bounce/complaint rates cross their thresholds. Check what's generating bounces (bad list hygiene, typo'd addresses) before it escalates.

---

## Common operations

### Send a test message

```bash
aws ses send-email \
  --from "no-reply@{{artifacts.email.domain}}" \
  --destination "ToAddresses=you@example.com" \
  --message 'Subject={Data=Test},Body={Text={Data=Hello from SES}}'
```

### Rotate SMTP credentials

Redeploy this instance — a fresh IAM access key (and derived SMTP password) is generated each time the underlying `aws_iam_access_key` is replaced. Update the app's stored credential immediately after.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-ses-email/operator.md
