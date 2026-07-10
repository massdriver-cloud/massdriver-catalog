---
templating: mustache
---

# Static Site Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Website URL | `{{artifacts.app.url}}` |
| Region | `{{params.region}}` |
| Index document | `{{params.index_document}}` |
| Error document | `{{params.error_document}}` |
| Cache max age | `{{params.cache_max_age_seconds}}` seconds |

Most commands below need the bucket name. It's the first label of the website URL's hostname — grab it once:

```bash
BUCKET=$(echo "{{artifacts.app.url}}" | sed -E 's|^https?://([^.]+)\..*|\1|')
```

---

## "The site is showing XML that says AccessDenied"

S3 is serving an error document *from S3 itself*, which means the public-read path is broken. Check the two things that make this site public, in order:

```bash
# 1. All four flags must be false — any true blocks the public policy
aws s3api get-public-access-block --bucket $BUCKET

# 2. The bucket must actually be public via its policy
aws s3api get-bucket-policy-status --bucket $BUCKET   # want IsPublic: true
aws s3api get-bucket-policy --bucket $BUCKET          # want s3:GetObject to Principal "*"
```

- **A flag is `true` or the policy is missing:** someone changed it outside of Massdriver (or an account-level Block Public Access setting was turned on). Redeploy this instance to stomp bucket-level drift. If it comes back `true` after a redeploy, check the *account-level* setting — it overrides everything: `aws s3control get-public-access-block --account-id YOUR_ACCOUNT_ID`.
- **Both look right but one page 403s:** that object may be missing — see "The site is gone" below.

## "I deployed changes but they aren't showing up"

1. **It's probably a cache.** Every file is served with `Cache-Control: max-age={{params.cache_max_age_seconds}}`. Until that many seconds pass, browsers and proxies won't re-fetch. Bypass your browser and check what S3 is actually serving:

   ```bash
   curl -s {{artifacts.app.url}} | head -20
   curl -sI {{artifacts.app.url}}   # check Last-Modified and Cache-Control
   ```

   If `curl` shows the new content, S3 is fine — it's browser cache. Hard-refresh, or wait out the max-age.

2. **If `curl` shows the old content too**, the deploy didn't upload the file. Files upload only when their content hash changes — confirm the changed files actually made it into `src/site/` in the published bundle version, then check the object timestamp:

   ```bash
   aws s3api head-object --bucket $BUCKET --key {{params.index_document}} \
     --query '{LastModified: LastModified, CacheControl: CacheControl}'
   ```

3. **While iterating**, set `cache_max_age_seconds` to `0` and redeploy — every request re-fetches, and stale caches stop being a variable.

## "The site is gone"

Work outward from the bucket:

```bash
# Does the bucket still exist?
aws s3api head-bucket --bucket $BUCKET

# Is website hosting still configured?
aws s3api get-bucket-website --bucket $BUCKET   # want IndexDocument: {{params.index_document}}

# Are the files still there?
aws s3 ls s3://$BUCKET/

# What does the endpoint itself say?
curl -sI {{artifacts.app.url}}
```

- **`head-bucket` 404s:** the bucket was deleted outside of Massdriver. Redeploy this instance — the site rebuilds completely from the bundle (a new random bucket suffix means a new URL; downstream consumers of the artifact pick it up automatically).
- **`get-bucket-website` errors:** website hosting was turned off. Redeploy to restore it.
- **Bucket and config fine but objects missing:** someone emptied the bucket. Redeploy — the site files live in git, not the bucket.
- **Everything above checks out but the URL times out:** make sure you're using the exact URL from the table above — website endpoints are region-specific and HTTP only (`http://`, not `https://`).
