# Artist Portal runbook

## The page loads but shows "This app has no database connection yet."

`DATABASE_HOST` or `DATABASE_SCHEMA` is not in the container's environment, which means the
`database` connection is not wired on the canvas. Those variables are only injected when the
`pg-table-set` component is actually linked to this app.

Check what the running revision was given:

```bash
gcloud run services describe {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --format="value(spec.template.spec.containers[0].env)"
```

If `DATABASE_SCHEMA` is missing, link `artists-dev-tables` to this app on the canvas and redeploy:

```bash
mass instance deploy artists-dev-portal -m "wire database connection" -f
```

Linking alone is not enough — the environment is only rebuilt on the next deploy.

## The page loads but shows "Could not reach the database: connection timeout expired"

The app resolved the database host but could not open a TCP connection to it. The shared
PostgreSQL instance has a private address only, so Cloud Run can reach it exclusively through a
Serverless VPC connector.

Almost always the `vpc_connector` connection is missing, or the connector is in a different region
than this service. A connector only serves Cloud Run services in its own region.

```bash
gcloud run services describe {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --format="value(spec.template.metadata.annotations)"
```

If there is no `run.googleapis.com/vpc-access-connector` annotation, link the shared network's
connector (`scp-dev-network`) to this app and redeploy. If the annotation is there, confirm the
connector's region matches `{{params.region}}` — the network bundle's own runbook covers resizing
and relocating it.

## The page loads but shows "Could not reach the database: permission denied for schema artist_portal"

The login exists but the grants are gone, or the app is pointed at a schema it does not own. This
is a `pg-table-set` problem, not a Cloud Run one — redeploying this app will not fix it.

```bash
mass instance deploy artists-dev-tables -m "reapply schema grants" -f
```

To look at the grants directly, run the Cloud SQL Auth Proxy — your laptop is not on the
instance's authorized-networks allowlist. Get the connection name first:

```bash
gcloud sql instances list --project=cory-sandbox-362007 --format="value(connectionName)"
```

```bash
cloud-sql-proxy --port 5433 cory-sandbox-362007:us-central1:db-scp-dev-db
```

Then, in another terminal (the password is on the `artists-dev-tables` instance's resource panel
in Massdriver — `psql -W` will prompt for it):

```bash
psql -h 127.0.0.1 -p 5433 -U artist_portal_app -d shared -W -c "\dn+ artist_portal"
```

## The page loads but shows "Could not reach the database: relation "artist_portal.artists" does not exist"

The app creates its own table on the first request, so this only appears when the `CREATE TABLE`
itself failed and the error was swallowed on an earlier request — usually because the login could
create a connection but not objects in the schema. Treat it as the `permission denied` case above:
redeploy `artists-dev-tables`, then reload the page to let the app create the table again.

## The table is empty and the example artists never appeared

The seed rows are only inserted when the table has zero rows. A genuinely empty table does get
reseeded on the next page load, so if real rows were deleted the five fictional example artists
come back — that is not recovery, it means the real rows are gone.

If the page shows `0 rows` in the footer and reloading does not change it, the insert is failing
rather than being skipped. That is a write-permission problem: see the `permission denied` entry
above.

## A CSV upload reports "Added 0 row(s)"

Either the file had no usable lines, or every line was treated as a header.

The parser skips the first row only when its first cell reads `name`. Blank lines are dropped. A
file whose rows are all empty strings adds nothing.

Columns must be in this order, and extra columns past the third are discarded:

```
name,genre,manager
Neon Harbour,synth-pop,R. Okafor
```

A file saved as UTF-16 from Excel arrives as unreadable characters rather than an error — re-save
it as plain CSV (UTF-8) and upload again.

## Every artist appears twice after an upload

Uploads append. There is no unique constraint on `name` and no duplicate check, so uploading the
same file twice inserts every row twice. Remove the extras directly:

```bash
psql -h 127.0.0.1 -p 5433 -U artist_portal_app -d shared -W -c "DELETE FROM artist_portal.artists a USING artist_portal.artists b WHERE a.id > b.id AND a.name = b.name;"
```

(Connect through the Cloud SQL Auth Proxy as above.)

## Cloud Run logs are empty — no request lines at all

Expected. The app suppresses the default per-request access log, so a healthy service writes
almost nothing to stdout. An empty log stream is not evidence that requests are failing or that
the container is not running.

Errors are not logged either — they are rendered into the page itself, in the orange box. Load the
page and read that text; it is the app's error output.

To confirm the service is actually up rather than silent:

```bash
gcloud run services describe {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --format="value(status.conditions)"
```

## The deploy fails at "verify_image" with "Cloud Build did not produce ... within 480s"

The build step ran but did not finish (or failed) before the wait expired. The error message
itself carries the real Cloud Build status and a direct log link — read that first:

- **status `QUEUED` or `WORKING`** — the build genuinely did not finish in time, usually a cold
  Cloud Build worker pool. Re-running the deploy retries from scratch with a fresh build.
- **status `FAILURE` or `INTERNAL_ERROR`** — open the log link. The most common cause is a real
  error in `build/app/main.py` or `build/app/Dockerfile`. Fix it and deploy again.
- **status `FAILURE` with a permission error in the log** — the Cloud Build service account lost
  its push binding on the registry. Redeploy this bundle; it re-creates the binding every time.

If the message shows "Build status: unknown", the trigger invocation never returned a usable build
ID — see the next entry instead.

## The deploy fails at "run_build" with a 403 or 404

The Cloud Build trigger invocation failed before any build ran.

- **403** — the credential deploying this bundle lacks `cloudbuild.builds.create` or
  `cloudbuild.triggers.get` on `cory-sandbox-362007`, or it cannot act as the build service
  account. Check its IAM roles.
- **404** — the trigger does not exist yet, almost always because this is the first deploy of a
  new instance and something upstream failed first. Read the deploy log from the top:

```bash
mass deployment list artists-dev-portal --limit 5
```

```bash
mass deployment logs 12345678-1234-1234-1234-123456789012
```

## The service is deployed but returns 403 Forbidden to real users

`public_access` is off, which is the default. Ingress is restricted to traffic originating inside
Google Cloud, so a browser on a laptop gets a 403 no matter who is signed in.

If this page is meant to be reachable from anywhere, turn `public_access` on and redeploy:

```bash
mass instance deploy artists-dev-portal --patch='.public_access = true' -m "open to the internet" -f
```

If it is meant to stay internal, that 403 is the bundle working correctly.

## The service returns 503, or a new revision never goes ready

```bash
gcloud run services describe {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --format="value(status.conditions)"
```

- **`PERMISSION_DENIED` or `NOT_FOUND` pulling the image** — the runtime service account's pull
  binding on the registry was revoked outside Massdriver. Redeploy; the binding is re-applied
  every deploy.
- **Revision stuck in `Retrying`** — the container is crashing at startup, not failing to pull.
  A missing `psycopg` or a syntax error in `main.py` shows up here:

```bash
gcloud run services logs read {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --limit=50
```

## A deploy fails within a minute with "Error acquiring the state lock"

Something else holds the OpenTofu state lock for this instance's `build` or `deploy` step. A
completely blank "Lock Info" block — no ID, no holder, no timestamp — is normal for this failure on
this backend and does not indicate a second problem.

```bash
mass deployment list artists-dev-portal --limit 5
```

- If the most recent deployment is `RUNNING`, `PENDING`, or `APPROVED`, leave it alone. It may
  legitimately hold the lock. Wait for a terminal status.
- If everything is terminal and the deploy still failed on the lock, the cause is almost always an
  `ABORTED` deployment whose provisioner had already started applying. Aborting only updates
  Massdriver's record — the OpenTofu process keeps running against real infrastructure and keeps
  the lock until it finishes on its own. For this bundle that is bounded by the 480s Cloud Build
  wait, so the lock clears by itself roughly 8–9 minutes after the abort.

Retry first. If it is stuck well past that window:

```bash
mass instance orphan artists-dev-portal
```

That resets the instance to `INITIALIZED`, aborts lingering deployment records, and clears the
lock, keeping the existing state files. Only add `--delete-state` if you also intend to discard
tracked infrastructure, which a lock problem never calls for.

Do not reach for `tofu force-unlock` — the conflict response carries no lock ID, so it would be a
blind unlock, and it leaves Massdriver's bookkeeping out of sync with the state backend.

Never clear a lock while a deployment for this instance is genuinely `RUNNING`, `PENDING`, or
`APPROVED`. Clearing a lock under a live apply is how state gets corrupted.

## Aborting a deployment did not stop it

Aborting is only safe for a deployment that has not started running — `PENDING` or `APPROVED`.

```bash
mass deployment get 12345678-1234-1234-1234-123456789012
```

Aborting a `RUNNING` deployment changes Massdriver's record to `ABORTED` but does not stop the
build or the apply underneath. That work continues unsupervised. To supersede a running
deployment, let it finish and then deploy the corrected configuration on top of what it left
behind.

## A change to main.py is not showing up

Every deploy rebuilds and re-pushes a fresh image under a tag unique to that deployment, so a
stale page means the service is still serving an older revision:

```bash
gcloud run services describe {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --format="value(status.latestReadyRevisionName)"
```

If the newest revision is not the one serving traffic, the new revision failed to go ready — see
the 503 entry above.

Publishing a new bundle version does not by itself redeploy anything. After publishing, move the
instance and deploy:

```bash
mass bundle publish --development --bundle-directory bundles/artist-portal
```

```bash
mass instance version artists-dev-portal@latest+dev
```

```bash
mass instance deploy artists-dev-portal -m "pick up main.py change" -f
```

## Rolling back

This bundle has no traffic splitting and no revision pinning — every deploy replaces all traffic
with a freshly built image. Roll back by returning to an older deployment of this instance, which
rebuilds that older source under a brand-new tag rather than resurrecting the old container.

Find a known-good deployment:

```bash
mass deployment list artists-dev-portal --limit 10 --status completed --action provision
```

Rolling back creates a proposed deployment, which then has to be approved before it runs:

```bash
mass instance rollback 12345678-1234-1234-1234-123456789012
```

```bash
mass deployment approve 87654321-4321-4321-4321-210987654321
```

## The first visit after a quiet period takes several seconds

`min_instances` is 0, so the service scales to zero when idle and the next request pays the
container start plus the first database connection. Keep one copy warm if that matters:

```bash
mass instance deploy artists-dev-portal --patch='.min_instances = 1' -m "keep one copy warm" -f
```

That bills continuously for the warm copy whether or not anyone visits.
