---
templating: mustache
---

# Storage bucket runbook

## The "5xx Error Rate" alarm fired

The bucket is returning server errors. Check the cloud provider's status page first — if the
storage backend is degraded there is nothing to fix here. If it is green, IAM is the next
suspect: some policy shapes surface a denial as a 5xx rather than a 403.

Error counts over the last hour:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name 5xxErrors \
  --dimensions Name=BucketName,Value={{artifacts.bucket.name}} Name=FilterId,Value=EntireBucket \
  --start-time $(date -u -d '1 hour ago' +%FT%TZ) \
  --end-time $(date -u +%FT%TZ) \
  --period 60 --statistics Sum
```

The failing requests themselves, from the newest access log:

```bash
LATEST=$(aws s3 ls s3://{{artifacts.bucket.name}}-access-logs/ | sort | tail -1 | awk '{print $4}')
aws s3 cp "s3://{{artifacts.bucket.name}}-access-logs/$LATEST" - | grep -E ' "[0-9]+ 5[0-9]{2} '
```

## The "Anonymous Access Anomaly" alarm fired on a private bucket

A request reached this bucket without authenticating. On a private bucket that number should be
zero. Confirm the bucket really is closed before you go looking for the source:

```bash
aws s3api get-public-access-block --bucket {{artifacts.bucket.name}}
aws s3api get-bucket-policy-status --bucket {{artifacts.bucket.name}}
aws s3api get-bucket-acl --bucket {{artifacts.bucket.name}}
```

```bash
aws s3api get-bucket-policy --bucket {{artifacts.bucket.name}} | jq -r '.Policy' | jq
```

If any of those come back public, page security and close the bucket before investigating how it
opened. `access_level` is `{{params.access_level}}` in this bundle, so a public result means
something was changed outside Massdriver and the next deploy will silently revert it — capture
the evidence first.

If everything reads private, the request was refused and the alarm is telling you someone is
probing. That is a security signal, not an outage.

## Someone overwrote or deleted an object and needs it back

{{#params.versioning_enabled}}
Versioning is on, so the old bytes are still there. List what survives for the object:

```bash
aws s3api list-object-versions --bucket {{artifacts.bucket.name}} --prefix uploads/report.pdf \
  --query 'Versions[].[VersionId,LastModified,IsLatest]' --output table
```

Copy the version you want back over the current one, using the `VersionId` from that listing:

```bash
aws s3api copy-object \
  --bucket {{artifacts.bucket.name}} \
  --copy-source "{{artifacts.bucket.name}}/uploads/report.pdf?versionId=3sL4kqtJlcpXroDTDmJ2rmSpXd3dIbrHY" \
  --key uploads/report.pdf
```

This adds a new version rather than removing the bad one, so the mistake stays in the history and
you can undo the undo.

If the object was deleted rather than overwritten, look for a delete marker in
`DeleteMarkers[]` instead of `Versions[]` — removing the marker restores the object.
{{/params.versioning_enabled}}
{{^params.versioning_enabled}}
Versioning is off on this bucket, so an overwritten or deleted object is gone. There is nothing
to recover and no command below will help.

Turn versioning on before this happens again. It only protects objects written after it is
enabled:

```bash
mass instance deploy {{slug}} -P '.versioning_enabled = true' -m "enable versioning" -f
```
{{/params.versioning_enabled}}

## An object will not delete, and neither will the bucket

{{#params.object_lock}}
Object lock is on with `{{params.object_lock_retention_days}}` days of retention. Every object is
immutable until its own retention expires, counted from when it was uploaded — not from now, and
not from when the bucket was created.

Nothing gets around this. Not an administrator, not the console, not root credentials, not
Massdriver. That is the entire point of compliance mode, and it is why the deploy that turned it
on could not be undone.

Two consequences worth planning for: storage only grows until the oldest objects age out, and
this bucket cannot be destroyed while any object is still under retention.
{{/params.object_lock}}
{{^params.object_lock}}
Object lock is off on this bucket, so this is not a retention hold. Check for a bucket policy or
an IAM boundary denying `s3:DeleteObject`, and for a delete marker you are mistaking for a
failure — with versioning on, a delete looks like it did nothing.

Note that turning object lock on is one-way. `object_lock` is marked immutable in this bundle
precisely so nobody flips it on during an incident and discovers next quarter that the bucket
cannot be emptied.
{{/params.object_lock}}

## Something outside the platform needs read access to one object, briefly

A pre-signed URL grants access to exactly one object for a fixed time, without changing the
bucket's access level and without issuing anyone credentials.

```bash
aws s3 presign s3://{{artifacts.bucket.name}}/uploads/report.pdf --expires-in 900
```

```bash
gcloud storage sign-url gs://{{artifacts.bucket.name}}/uploads/report.pdf --duration=15m
```

The URL carries the authorisation, so anyone who gets it has the object. Fifteen minutes is a
reasonable default; a URL good for a week is a credential you cannot revoke.

## Changing `bucket_name` or `object_lock`

Both are immutable. Buckets cannot be renamed and object lock cannot be switched on or off after
creation, so changing either means a new bucket and a copy.

1. Count what you are moving, so you can tell when the copy is complete:

```bash
aws s3 ls s3://{{artifacts.bucket.name}}/ --recursive | wc -l
```

2. Deploy a second bucket instance with the new settings, then set its deployed name here — the
   provisioner appends a unique suffix, so it will not be exactly what you typed in the form:

```bash
NEW_BUCKET=merch-inventory-assets-4f2a
```

3. Copy:

```bash
aws s3 sync s3://{{artifacts.bucket.name}}/ "s3://$NEW_BUCKET/"
```

`sync` copies current versions only. Object history does not come across, so if you are moving a
bucket because of a compliance requirement, check whether that requirement covers the history
too.

4. Re-link every consumer to the new bucket on the canvas and redeploy them.
5. Empty and destroy the old bucket.

{{#params.object_lock}}
Step 5 will fail while any object is still under its `{{params.object_lock_retention_days}}`-day
retention. You will be paying for both buckets until the last object ages out. Budget for it.
{{/params.object_lock}}
