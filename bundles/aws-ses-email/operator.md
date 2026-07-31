---
templating: mustache
---

# Email Runbook

## Sending fails: domain not verified

SES cannot send from `{{artifacts.email.domain}}` until DNS verification completes.

```bash
aws ses get-identity-verification-attributes --identities {{artifacts.email.domain}}
aws ses get-identity-dkim-attributes --identities {{artifacts.email.domain}}
```

Take the three DKIM tokens from the second command and add them at your DNS provider as:

```
<token>._domainkey.{{artifacts.email.domain}}.  CNAME  <token>.dkim.amazonses.com.
```

Verification usually completes within a few minutes to a few hours after the records propagate. Until then, `SendEmail`/`SendRawEmail` calls fail.

## Sending fails: account still in the SES sandbox

New AWS accounts can only send to verified addresses until production access is granted.

```bash
aws sesv2 get-account | grep -A2 ProductionAccessEnabled
```

If `ProductionAccessEnabled` is false, request production access in the SES console.

## Alarms

### Bounce or complaint rate climbing

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/SES --metric-name Reputation.BounceRate \
  --start-time $(date -u -d '1 day ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 3600 --statistics Maximum
```

AWS suspends sending when bounce or complaint rates cross its thresholds. Identify the source of the bounces (stale lists, mistyped addresses) before that happens.

## Common operations

### Send a test message

```bash
aws ses send-email \
  --from "no-reply@{{artifacts.email.domain}}" \
  --destination "ToAddresses=you@example.com" \
  --message 'Subject={Data=Test},Body={Text={Data=Hello from SES}}'
```

### Rotate SMTP credentials

Redeploy this instance. A fresh IAM access key (and derived SMTP password) is generated when the underlying `aws_iam_access_key` is replaced. Update the app's stored credential immediately after.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-ses-email/operator.md
