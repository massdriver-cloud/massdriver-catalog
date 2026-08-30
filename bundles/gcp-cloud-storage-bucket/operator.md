# Cloud Storage Bucket runbook

## A deploy fails with `Permission denied` or `403`

The GCP service account connected to this bundle cannot manage Cloud Storage or (if encryption
with your own key is on) Cloud KMS.

Check that the Cloud Storage API is enabled on the project:

```
https://console.cloud.google.com/apis/library/storage.googleapis.com?project=cory-sandbox-362007
```

If the API is on, the service account is missing a role. It needs `roles/storage.admin` at
minimum. If **Encrypt With A Key You Control** is on, it also needs `roles/cloudkms.admin` (or
`roles/owner`).

## A deploy fails with `googleapi: Error 409: ... conflict` on the bucket

Bucket names are unique across every GCP project on Earth, not just this one — someone else, in
any organization, may already be using the exact name this bundle generated. This is rare because
the name includes your project and environment, but not impossible.

Change **Bucket Name** to something more specific and redeploy. There is nothing else to fix;
this is not a permissions problem.

## Destroying this instance fails with "bucket is not empty"

This is intentional. The bucket does not auto-delete its contents on teardown — empty it by hand
first:

{{#resources.bucket}}
```bash
gsutil -m rm -r gs://{{resources.bucket.name}}/**
```
{{/resources.bucket}}

Then retry the decommission. If versioning was ever on, also remove noncurrent versions — plain
`rm` leaves them behind:

{{#resources.bucket}}
```bash
gsutil -m rm -a gs://{{resources.bucket.name}}/**
```
{{/resources.bucket}}

## A workload cannot read or write to the bucket

Confirm the consuming bundle actually connected to this bucket and picked a policy — **Read**,
**Read and Write**, or **Admin**. If it picked **Read** and is trying to write, that is working
as designed; switch its connection to **Read and Write**.

If the policy looks right, check the binding actually landed:

{{#resources.bucket}}
```bash
gsutil iam get gs://{{resources.bucket.name}}
```
{{/resources.bucket}}

The consuming workload's service account should appear with the expected role.

## Files are disappearing that nobody deleted

**Automatically Delete Files After (days)** is on and set lower than you think. Any object older
than that many days is deleted permanently the next time GCS runs its lifecycle sweep (up to 24
hours after it becomes eligible — not deleted the instant it crosses the threshold). Check the
setting on this instance's config and raise it, or set it to 0 to disable, then redeploy. Nothing
already deleted comes back unless **Keep Old Versions of Files** was also on.

## Compliance scan shows findings on a `-logs` bucket you didn't create directly

Turning on **Log Who Accesses This Bucket** creates a second, dedicated bucket
(`{{resources.bucket.name}}-logs`) to receive the access logs. That bucket will always show two
findings — "Bucket should log access" and "Bucket should not log to itself" — because it has no
logging of its own. Configuring it to log to itself would just duplicate every entry into the
thing generating it; configuring it to log to yet another bucket only pushes the same problem one
level further out. Google's own guidance for GCS access logging is that the destination bucket
should not have logging enabled, so this is expected on every deploy where access logging is on,
in every environment — it is not something to chase down or a regression from something you
changed. It is not skipped in `.checkov.yml`, so it stays visible in scan output rather than
being hidden.

## Customer-managed encryption errors ("KMS key not found" / "permission denied" on the key)

**Encrypt With A Key You Control** creates a Cloud KMS key ring and key the first time it's
turned on, and grants the Cloud Storage service agent permission to use it. If this breaks:

- Confirm the key ring and key still exist in the same region as the bucket — Cloud KMS key
  rings cannot be renamed or moved, and are never deleted by this bundle even if the setting is
  turned back off.
- Confirm the Cloud Storage service agent still has `roles/cloudkms.cryptoKeyEncrypterDecrypter`
  on the key. It's re-granted on every deploy, so a manual revocation elsewhere in the console is
  the usual cause if it's missing.

If this instance was ever fully torn down and redeployed with encryption on both times, you'll
see a *different* key ring name each time (a random suffix, not just `md_metadata`-derived). That
is expected: Cloud KMS never actually deletes a key ring or key, so reusing the old name after a
teardown would fail with "already exists" against the still-there-but-orphaned original. Those
orphaned key rings are harmless (no cost, nothing points at them) but do accumulate in the
project across every full teardown-and-recreate; if that matters for your organization's KMS
hygiene, list them periodically:

{{#resources.bucket}}
```bash
gcloud kms keyrings list --location={{resources.bucket.region}} --project=cory-sandbox-362007
```
{{/resources.bucket}}

Turning **Encrypt With A Key You Control** off does not decrypt existing objects or re-encrypt
them with a Google-owned key — it only changes what new objects use. The key itself is never
deleted (GCP does not support deleting KMS keys), so old objects stay readable as long as nobody
disables the key by hand.

## Costs are climbing

Check what's actually driving it:

- **Storage Class** — Nearline/Coldline/Archive are cheaper per GB but charge a fee for deleting
  or overwriting data before the minimum storage duration (30/90/365 days). Rewriting the same
  files often on a cold class costs more than Standard would have.
- **Keep Old Versions of Files** — every overwritten or deleted file's previous copy is retained
  and billed. If nothing prunes old versions, this grows without bound.
- **Log Who Accesses This Bucket** — access logs land in a second bucket that is never
  auto-pruned by this bundle. If it's been on a long time, check its size:

{{#resources.bucket}}
```bash
gsutil du -sh gs://{{resources.bucket.name}}-logs
```
{{/resources.bucket}}
