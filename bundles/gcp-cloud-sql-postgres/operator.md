# PostgreSQL database runbook

## App can't connect — connection times out

Almost always one of three things:

1. The app isn't deployed in a region with a path to this database's network. Check the app's
   Cloud Run region and this instance's region:

{{#resources.database}}
```bash
gcloud sql instances describe {{resources.database.id}} --format="value(region)"
```
{{/resources.database}}

2. The app's component isn't actually linked to this one on the canvas — env vars for
   `DATABASE_HOST` etc. are only populated when the connection exists. Check the canvas, not just
   the app's config.
3. The platform network's Private Service Access peering is down or was never finished. That's
   diagnosed and fixed in the network bundle's own runbook, not here — this bundle has no control
   over the peering itself, only whether it required one at deploy time.

## Deploy fails with "instance requires Private Service Access" or a private IP allocation error

This bundle refuses to deploy if the connected network doesn't already have Private Service Access
turned on — that's a precondition check, not something that fails partway through. Turn on
"Private Service Access" on the network component and redeploy the network first, then redeploy
this database.

If Private Service Access is already on but the deploy still fails allocating an address, the
network's reserved peering range is full. That's fixed by widening the range on the network
bundle — see its runbook, not this one.

## Deploy fails trying to change Database Name, Username, or PostgreSQL Version

Those three fields are locked after creation on purpose — changing any of them means a different
database or a major-version migration, not an in-place edit. If you actually need a different
value, stand up a new database component instead of trying to force this one to change, and
migrate data across deliberately.

## Need to see or rotate the password

The password isn't visible anywhere in plain text except what's handed to a connected app at
deploy time. To rotate it, redeploy this instance — a fresh password is generated and every
connected app picks up the new value on its next deploy. There's no in-place "change password"
action; a rotation is a redeploy.

## Restoring from a backup

{{#resources.database}}
List available backups and on-demand restore points:

```bash
gcloud sql backups list --instance={{resources.database.id}}
```

Restoring in place overwrites the current database — for anything you're not sure about, clone to
a new instance first and verify before touching the original:

```bash
gcloud sql instances clone {{resources.database.id}} <new-instance-name> --point-in-time=<RFC3339 timestamp>
```
{{/resources.database}}

If "Keep daily backups?" was turned off, there is nothing to restore from — that setting also
controls point-in-time recovery, not just nightly snapshots.

## Trying to delete this and it won't go

"Prevent accidental deletion?" is on. Turn it off and redeploy first, then decommission — this is
intentional friction, not a bug.

## CPU or connections maxed out, queries slow

Check current load before assuming you need a bigger size:

{{#resources.database}}
```bash
gcloud sql operations list --instance={{resources.database.id}} --limit=10
```
{{/resources.database}}

If it's consistently pegged rather than a one-off spike, bump "How much traffic do you expect?" up
a size and redeploy. That's an online resize — it takes a few minutes but doesn't require
recreating the instance or losing data.
