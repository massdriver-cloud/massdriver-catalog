# GCP Cloud Storage Bucket

Creates a place in Google Cloud to store files — uploads, exports, backups, generated reports,
anything your app needs to keep as a file rather than a database row.

## What you get

One Cloud Storage bucket in the region you pick. It is private by default: nothing outside of
what you explicitly connect can read or write to it, and it can never be made public by
accident.

## Settings

**Bucket Name** — a short name for what's going in this bucket, like `uploads` or `exports`.
Combined with your project and environment behind the scenes to make it globally unique. You
cannot rename it later.

**Location** — the region your files live in. Pick the region closest to whatever reads and
writes to this bucket, usually the same region as your app. You cannot change this later.

**Storage Class** — how often you'll access these files. Standard is right for anything read or
written regularly. The colder classes (Nearline, Coldline, Archive) are cheaper to store but
cost more, and are slower, to read back — and charge a penalty if you delete or overwrite data
too soon after writing it. If you're not sure, leave this on Standard.

**Keep Old Versions of Files** — when something overwrites or deletes a file, the previous copy
is kept instead of lost for good. Worth turning on for anything you can't easily regenerate.
Every version kept uses extra storage.

**Log Who Accesses This Bucket** — records every read and write to a second, dedicated bucket,
so you can review it later or figure out what happened after an incident. Adds a small amount of
storage cost for the logs themselves.

**Encrypt With A Key You Control** — Google encrypts everything in this bucket automatically
either way. Turning this on adds a key you control (in Cloud KMS) as an extra layer, so access to
the data can be cut off by disabling the key. Worth it for sensitive data; unnecessary for
anything else.

**Automatically Delete Files After (days)** — permanently deletes files once they reach this
age. Good for temporary or scratch data. Set to 0 to keep files until someone deletes them by
hand.

## Connecting other things to it

This bundle produces a **Storage Bucket** resource. Any bundle that needs to read or write files
can connect to it and pick a policy: **Read** for read-only access, **Read and Write** for normal
application use, or **Admin** for something that also needs to manage the bucket's own settings.

## Using it from your app

The bucket name and `gs://` URL are on the resource in Massdriver after deploying. Any of
Google's client libraries (`google-cloud-storage` in Python, Node, Go, etc.) will pick up
credentials automatically from the environment your app runs in — you just need the bucket name.
