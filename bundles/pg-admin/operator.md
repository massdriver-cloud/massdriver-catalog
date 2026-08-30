# pg-admin runbook

## The URL returns 403 Forbidden

Expected. `public_access` is off, so Cloud Run rejects anything that does not come from inside the
network. Go through a proxy:

```bash
gcloud run services proxy pg-admin-scp-dev-pgadmin-XXXX \
  --project cory-sandbox-362007 --region us-central1 --port 8080
```

Get the exact service name from the instance's resource, or:

```bash
gcloud run services list --project cory-sandbox-362007 --region us-central1 --format="value(name)"
```

If you were expecting it to be reachable directly, check whether somebody turned `public_access`
on. It should be off, and the README says why.

## Sign-in rejects the password you set

pgAdmin creates its user account from `PGADMIN_DEFAULT_EMAIL` and `PGADMIN_DEFAULT_PASSWORD` **the
first time it boots with an empty config file**. Change the password on the component afterwards
and the running container keeps the old one, because its config file already exists.

The container has no persistent disk, so a restart fixes it:

```bash
mass instance deploy scp-dev-pgadmin -m "restart to pick up new sign-in" -f
```

Once it restarts, the new password applies.

## Signed in, but the server list is empty

The startup script writes `servers.json` before handing over to pgAdmin, so an empty list means it
did not run or the connection was missing. Check the container logs:

```bash
gcloud run services logs read pg-admin-scp-dev-pgadmin-XXXX \
  --project cory-sandbox-362007 --region us-central1 --limit 50
```

Then confirm the `database` slot is wired on the canvas. It takes the `postgres-database` resource
published by `gcp-cloud-sql-postgres` — the cluster itself, not a `postgres-table-set` belonging to
an app.

## The server is listed but connecting times out

pgAdmin is reaching the database's private address over the serverless connector, so this is a
network path problem rather than a credential one.

Confirm the `vpc_connector` slot is connected. Without it, Cloud Run has no route to a private IP
and the connection hangs until it gives up.

## Connecting asks for a password

The startup script writes a `.pgpass` and points the server entry at it. libpq silently ignores a
passfile whose permissions are wider than `0600`, and the symptom is exactly this — a prompt where
there should not be one.

Type the password to get on with your work, then check the logs for an error from the `chmod` in
the startup script.

## Everything you saved has disappeared

Working as designed, and worth reading the README section about it. Cloud Run's filesystem does not
survive a restart, so pgAdmin's config database is rebuilt from scratch on every boot. Saved
queries and preferences do not persist.

Keep queries somewhere else. Anything you want to run again belongs in a file, not in the console.

## Sign-in works, then immediately bounces back to the sign-in page

This is what a second instance would cause — the session lives in a local file, so a request landing
on a different container has no session.

Scaling is hardcoded to exactly one instance, so this should be impossible. If it happens, check
whether the deployed revision actually has `min_instance_count = 1` and `max_instance_count = 1`:

```bash
gcloud run services describe pg-admin-scp-dev-pgadmin-XXXX \
  --project cory-sandbox-362007 --region us-central1 \
  --format="value(spec.template.scaling)"
```

## The container starts and then exits

pgAdmin needs about a gigabyte. On `small` it starts, exhausts its memory during initialisation,
and Cloud Run restarts it in a loop.

Move the component to `medium` and redeploy.

## Decommission

Removes the Cloud Run service and its runtime service account. The database is untouched — this
bundle only connects to it, and creates nothing inside it.
