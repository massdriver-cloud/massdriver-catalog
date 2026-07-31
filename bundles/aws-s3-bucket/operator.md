---
templating: mustache
---

# Object Storage Runbook

## Bucket unexpectedly public

```bash
aws s3api get-public-access-block --bucket {{artifacts.bucket.name}}
# All four settings should be true. A false value means the bucket was
# modified outside Massdriver — treat it as an incident.
```

Redeploying this instance restores the public access block.

## Common operations

### List recent uploads

```bash
aws s3 ls s3://{{artifacts.bucket.name}}/ --recursive --human-readable | tail -20
```

### Audit who can decrypt objects

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
Versioning is off on this bucket. Deletes and overwrites are permanent; there is no previous version to restore from.
{{/params.enable_versioning}}

## Disaster recovery

Durability is provided by S3 itself; there is no failover to manage. The operational risks are permission changes and accidental deletes. If `force_destroy` is `true`, the bucket can be destroyed with objects still in it.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/aws-s3-bucket/operator.md
