# Firestore runbook

## A deploy fails with `Permission denied` or `403`

The GCP service account connected to this bundle cannot manage Firestore.

Check that the Firestore API is enabled on the project:

```
https://console.cloud.google.com/apis/library/firestore.googleapis.com?project=PROJECT_ID
```

If the API is on, the service account is missing a role. It needs `roles/datastore.owner` at
minimum, or `roles/owner`.

## A deploy fails with "database already exists" or a Datastore-mode conflict

A GCP project can only run Firestore in one mode at a time by default. If this project already
has a database — created by hand, by another tool, or in the legacy Datastore mode — creating a
second, differently-moded database through this bundle will fail. Check what's already there:

```bash
gcloud firestore databases list --project=PROJECT_ID
```

If an unrelated database is sitting in the way, this bundle is pointed at the wrong project, or
someone needs to decide which database wins before this bundle can deploy cleanly here.

If instead the database listed is one this instance was just trying to create — you'll recognize
it by name, `db-<this instance's name prefix>` — this is a different, known issue: the Google
provider occasionally reports `Provider produced inconsistent result after apply` on the very
first database created in a project right after the Firestore API finishes enabling. The database
is actually created successfully; only the provider's follow-up read fails, so Terraform never
records it in state, and every retry then collides with the (correctly created) database it
doesn't know about. Fix it by importing the orphan back into state on the next deploy:

1. Temporarily add an `import` block to `src/main.tf`:
   ```hcl
   import {
     to = google_firestore_database.main
     id = "projects/PROJECT_ID/databases/db-<this instance's name prefix>"
   }
   ```
2. Publish and redeploy — this absorbs the existing database into state instead of trying to
   create it again.
3. Remove the `import` block and publish again; it was only needed for the one-time recovery.

## Removing this component fails with a delete-protection error

**Prevent Accidental Deletion** is on. This is intentional — it stops the database from being
deleted by mistake, including via the normal remove-this-component flow. To actually remove it:

1. Redeploy this instance with **Prevent Accidental Deletion** turned off.
2. Then remove the component (or decommission the instance).

There is no way to force past this from the Massdriver side; the GCP API itself refuses the
delete while protection is on.

## A workload cannot read or write to the database

Confirm the consuming bundle actually connected to this database and picked a policy — **Read**,
**Read and Write**, or **Admin**. If it picked **Read** and is trying to write, that is working as
designed.

If the policy looks right, check the binding actually landed. Firestore IAM is granted at the
project level, not on the individual database, so look at the project's bindings:

```bash
gcloud projects get-iam-policy PROJECT_ID --flatten="bindings[].members" --filter="bindings.role:roles/datastore"
```

The consuming workload's service account should appear with the expected role. If this project
ever ends up with a second Firestore database, remember that this same binding grants access to
both — there is no per-database IAM scoping.

## Recovering deleted or corrupted data

Only possible if **Keep A Rolling 7-Day Backup** was on *before* the data was lost, and only for
the last 7 days. Firestore's point-in-time recovery restores into a new database, it does not
overwrite the live one:

```bash
gcloud firestore databases restore \
  --source-database=projects/PROJECT_ID/databases/DATABASE_NAME \
  --destination-database=DATABASE_NAME-restored \
  --snapshot-time="2026-08-10T12:00:00Z"
```

Then point a temporary client at the restored database to pull back what's needed before deciding
what to do with it — do not delete the restored copy until you've confirmed the data is what you
expected.

## Costs are climbing

Firestore bills for reads, writes, deletes, and storage — not a flat instance price. Check what's
driving it:

- **Keep A Rolling 7-Day Backup** roughly doubles the storage cost for any data it covers. If a
  workload rewrites the same documents constantly, this adds up fast.
- A workload with a hot loop reading or writing far more often than expected is usually the
  actual cause, not the database settings. Check the project's Firestore usage in the console
  before changing anything here.
