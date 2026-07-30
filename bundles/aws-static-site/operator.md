---
templating: mustache
---

# Marketing Static Site Runbook

## Alarms

### 5xx error rate up

Usually the origin (S3) is returning errors CloudFront cannot serve around. Check that the bucket still exists, the OAC bucket policy has not been hand-edited, and the ACM certificate has not expired.

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront --metric-name 5xxErrorRate \
  --dimensions Name=DistributionId,Value=<dist-id> --region us-east-1 \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --statistics Average
```

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

### Verify the origin bucket is not publicly reachable

```bash
aws s3api get-public-access-block --bucket <bucket-name-from-instance-panel>
```

### Test a redirect

```bash
curl -I https://{{params.domain_name}}/blog
# Expect a 301/302/308 with a Location header, per the redirects list.
```

## Disaster recovery

The distribution and bucket are fast to recreate, and the site content can be re-uploaded from the app repo's build pipeline. There is no state to protect in this bundle; the source of truth is the site's repository.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-static-site/operator.md
