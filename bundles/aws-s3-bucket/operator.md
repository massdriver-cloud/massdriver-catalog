---
templating: mustache
---

# Object Storage Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Bucket | `{{artifacts.bucket.name}}` |
| Region | `{{artifacts.bucket.region}}` |
| KMS key | `{{artifacts.bucket.kms_key_arn}}` |
| Versioning | `{{params.enable_versioning}}` |

### Access policies

{{#artifacts.bucket.policies}}
- `{{name}}` — `{{id}}`
{{/artifacts.bucket.policies}}

---

## Common operations

### Confirm the bucket is actually private

```bash
aws s3api get-public-access-block --bucket {{artifacts.bucket.name}}
# Every field should read true. If any read false, something outside
# Massdriver modified this bucket directly — treat it as an incident.
```

### List recent uploads

```bash
aws s3 ls s3://{{artifacts.bucket.name}}/ --recursive --human-readable | tail -20
```

### Find who can decrypt objects

```bash
aws kms get-key-policy --key-id {{artifacts.bucket.kms_key_arn}} --policy-name default
```

{{#params.enable_versioning}}
### Recover a deleted or overwritten object

```bash
aws s3api list-object-versions --bucket {{artifacts.bucket.name}} --prefix <key>
aws s3api get-object --bucket {{artifacts.bucket.name}} --key <key> --version-id <version-id> restored-file
```
{{/params.enable_versioning}}
{{^params.enable_versioning}}
**Versioning is off.** A delete or overwrite here is permanent — there's no previous-version fallback to restore from.
{{/params.enable_versioning}}

---

## Disaster recovery

Object storage doesn't fail over the way a database does — the durability comes from S3 itself. The operational risk here is almost always **wrong permissions or an accidental delete**, not an outage. If `force_destroy` is `true`, treat this bucket as disposable — assume it can be emptied with no warning.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-s3-bucket/operator.md
