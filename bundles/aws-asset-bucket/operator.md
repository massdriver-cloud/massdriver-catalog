---
templating: mustache
---

# Asset Bucket Runbook

{{#resources.bucket}}

## Application gets AccessDenied reading or writing files

Symptom: the application logs `AccessDenied` or `403` on S3 calls that used to work.

First confirm which policy the caller was granted, then confirm the role actually has it
attached:

```bash
aws iam list-attached-role-policies --role-name <caller-execution-role>
```

The three policies published by this bucket end in `-read-`, `-write-`, and `-admin-`. A
caller that only has `read` will fail on uploads — that is the most common cause. Change the
policy selection in the consuming bundle's form and redeploy it.

If the right policy is attached and calls still fail, the KMS key is the next suspect. Every
object here is encrypted, so a caller needs KMS permission as well as S3 permission. All three
published policies include it, but a hand-written policy usually does not:

```bash
aws s3api head-object --bucket {{resources.bucket.name}} --key <some-key>
```

An error mentioning `KMS.NotFoundException` or `AccessDenied` on `kms:Decrypt` confirms it.

## Uploads from a web page fail with a CORS error

Symptom: the browser console shows a CORS error; the same upload works from a terminal.

Check what origins the bucket currently allows:

```bash
aws s3api get-bucket-cors --bucket {{resources.bucket.name}}
```

If this returns `NoSuchCORSConfiguration`, the origin list is empty — add the site to
**Browser Origins Allowed to Upload** and redeploy. If it returns a list, compare it exactly
against the page's origin. Scheme and port count: `https://example.com` does not match
`http://example.com` or `https://www.example.com`.

## Storage bill is climbing

Symptom: bucket cost grows faster than the amount of live data.

Old versions are the usual cause. Compare total size against current-version size:

```bash
aws s3api list-object-versions --bucket {{resources.bucket.name}} \
  --query 'length(Versions[?IsLatest==`false`])'
```

A large number here means versions are accumulating. Confirm the expiry rule is actually in
place:

```bash
aws s3api get-bucket-lifecycle-configuration --bucket {{resources.bucket.name}}
```

Look for a `housekeeping` rule with `NoncurrentVersionExpiration`. If it is missing, the
deploy did not finish — redeploy. If it is present, lower **Delete Old Versions After**.

Incomplete multipart uploads also accumulate silently and are invisible in the console:

```bash
aws s3api list-multipart-uploads --bucket {{resources.bucket.name}}
```

The housekeeping rule aborts these after seven days.

## Recovering a deleted or overwritten file

With versioning on, a delete just hides the file behind a delete marker. List what is there:

```bash
aws s3api list-object-versions --bucket {{resources.bucket.name}} --prefix <key>
```

Restore a specific version by copying it back over the current one:

```bash
aws s3api copy-object --bucket {{resources.bucket.name}} \
  --copy-source "{{resources.bucket.name}}/<key>?versionId=<version-id>" \
  --key <key>
```

This only works within the retention window set by **Delete Old Versions After**. Past that,
the old versions are gone.

## Deploy fails saying the bucket already exists

Symptom: `BucketAlreadyExists` or `BucketAlreadyOwnedByYou` on provision.

S3 names are global. The random suffix normally prevents this, so a collision usually means
the same bucket is being re-created after a decommission that did not finish emptying it.
Check whether it still exists:

```bash
aws s3api head-bucket --bucket {{resources.bucket.name}}
```

If it does and it is yours, empty and remove it before redeploying — S3 will not delete a
bucket that still holds objects or versions.

{{/resources.bucket}}

{{^resources.bucket}}

This bucket has not been deployed yet. Deploy it, then return here for operational procedures.

{{/resources.bucket}}
