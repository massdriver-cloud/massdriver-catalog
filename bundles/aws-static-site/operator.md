---
templating: mustache
---

# Marketing Static Site Runbook

> **Templating context:** `slug`, `params`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Domain | `{{params.domain_name}}` |
| Price class | `{{params.price_class}}` |
| Redirect count | {{params.redirects.length}} |

---

## Common operations

### Find the CloudFront domain to point DNS at

```bash
aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='{{slug}}'].DomainName" --output text
```

### Invalidate the cache after a content deploy

```bash
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='{{slug}}'].Id" --output text)
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"
```

### Confirm the bucket really isn't publicly reachable

```bash
aws s3api get-public-access-block --bucket <bucket-name-from-instance-panel>
```

### Test a redirect

```bash
curl -I https://{{params.domain_name}}/blog
# Expect a 301/302/308 with a Location header, per your redirects list.
```

---

## Active alarms — what they mean

### 5xx error rate up

Usually means the origin (S3) is returning errors CloudFront can't smooth over — check the bucket still exists, the OAC bucket policy hasn't been hand-edited, and the ACM certificate hasn't expired.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront --metric-name 5xxErrorRate \
  --dimensions Name=DistributionId,Value=<dist-id> --region us-east-1 \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Average
```

---

## Disaster recovery

There's no database here — the content lives in S3 and your own build pipeline can always re-upload it. The distribution and bucket are cheap and fast to recreate; the thing to protect against is losing the original site source, which lives in your app repo, not in this bundle.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-static-site/operator.md
