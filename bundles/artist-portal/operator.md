# Cloud Run runbook

## The deploy fails at "verify_image" with "Cloud Build did not produce ... within 480s"

The build step ran but didn't finish (or failed) before the wait expired. The error message
itself includes the real Cloud Build status and a direct log link — read that first:

- **status `QUEUED` or `WORKING`** — the build genuinely didn't finish in time (a much bigger
  app, or a cold Cloud Build worker pool). Re-running the deploy retries from scratch with a
  fresh build; if this keeps happening for this app, that's a signal the fixed 480s wait needs
  raising in the template.
- **status `FAILURE` or `INTERNAL_ERROR`** — open the log link. The most common cause is a real
  error in the app's `Dockerfile` or source (`docker build` failed). Fix the app code; it
  rebuilds on the next deploy.
- **status `FAILURE` with a permission error in the log** — the Cloud Build service account lost
  its `roles/artifactregistry.writer` binding on the registry. Redeploy this bundle; it re-creates
  the binding every time.

If the error message shows "Build status: unknown", the trigger invocation itself
(`data.http.run_build`) never returned a usable build ID — check the "run_build" failure below
instead.

## The deploy fails at "run_build" with a 403 or 404

The Cloud Build trigger invocation itself failed, before any build ran.

- **403** — the credential deploying this bundle lacks `cloudbuild.builds.create` /
  `cloudbuild.triggers.get` on the project. Check its IAM roles.
- **404** — the trigger doesn't exist yet, almost always because this is the very first deploy of
  a brand-new instance and something upstream failed first. Check the full deploy log from the
  top, not just this step.

## The service is deployed but returns 403 Forbidden to real users

`public_access` is off (the default). If this service is meant to be reachable by anyone with
the URL, turn `public_access` on and redeploy. If it's meant to stay private, the caller needs
`roles/run.invoker` on this service and a valid identity token — it isn't supposed to work
without one.

## The service returns 503, or a new revision never goes ready (image pull failure)

The build step always succeeds before the deploy step runs (a failed build step halts the whole
deployment), so a pull failure here means something changed between the two — most often a stale
IAM binding.

```bash
gcloud run services describe {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --format="value(status.conditions)"
```

- **`PERMISSION_DENIED` / `NOT_FOUND` pulling the image** — the runtime service account's
  `roles/artifactregistry.reader` binding on the registry is missing or was revoked outside
  Massdriver. Redeploy this bundle; the binding is re-applied every deploy.
- **Revision stuck in `Retrying`** — the container is crashing on startup, not failing to pull.
  Check the revision's own logs, not the build's:
  ```bash
  gcloud run services logs read {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --limit=50
  ```
- **503 on individual requests, service otherwise `Ready`** — the app itself is erroring or
  timing out per-request. This is application-level; the platform only guarantees the container
  is running, not that every request inside it succeeds.

## The service is deployed but times out or refuses connections from a database/bucket/Firestore it's connected to

Check which optional connection is missing, not broken:

- **Database** — confirm the `database` connection is actually wired to this instance, and that
  the network's Serverless VPC connector is in the *same region* as `{{params.region}}`. A
  connector only serves Cloud Run services in its own region.
- **Bucket / Firestore** — these don't need the VPC connector (they're reached over Google's own
  network, not privately), so a timeout here is almost always a missing IAM binding rather than
  routing. Redeploy — both bindings are re-applied on every deploy.

## Cold starts are hurting latency

`min_instances` is 0, so the service scales to zero when idle and the next request pays the
startup cost. Raise `min_instances` to 1 (or more) to keep it warm — this has an ongoing cost per
instance kept running, regardless of traffic.

## Rolling back to a previous version

This bundle has no traffic-splitting or revision-pinning of its own — every deploy replaces 100%
of traffic with a freshly built image. To roll back, redeploy an *older Massdriver deployment* of
this instance (its bundle version and params, not just its params): find it in the deployment
history and re-run it. Because the app source lives inside the bundle package itself, that
rebuilds the exact old code under a brand-new image tag and Cloud Run revision — same behavior as
the original, not a resurrection of the old container image.

## Costs are climbing

Two independent levers: `max_instances` caps the ceiling under load (check if traffic actually
needs it that high), and `size` sets the CPU/memory of every copy (a service sized for peak load
running at `min_instances: 1` all day is a bigger bill than the same service that scales to zero).

## An app-code change isn't showing up after deploy

Confirm the deploy actually redeployed rather than just picking up a new bundle release with the
same param set — every deploy always rebuilds and re-pushes a fresh image (the tag is unique per
deployment), so if the old behavior is still showing up, check that the Cloud Run *revision* the
service is now serving is actually the new one:

```bash
gcloud run services describe {{resources.service.name}} --region={{resources.service.region}} --project={{dependencies.gcp_service_account.project_id}} --format="value(status.latestReadyRevisionName)"
```
