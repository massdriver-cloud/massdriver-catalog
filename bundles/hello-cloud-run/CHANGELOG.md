# Changelog

## 0.0.0

Initial release.

- Two-step pipeline: `build` archives `build/app/` and runs it through Cloud Build to produce a
  container image, `deploy` deploys that image to Cloud Run
- Both steps independently derive the same image tag from
  `md_metadata.package.deployment_enqueued_at`, so no output is passed between steps
- `time_sleep.wait_for_build` is keyed on the image tag. Without that key it only ever slept on an
  instance's first deploy — every later deploy reused the already-complete resource from state and
  checked Artifact Registry while the new build was still `QUEUED`, failing with a 404 after
  supposedly waiting 480s
- A `data.http.build_status` read after the wait, so a failed `verify_image` check reports the real
  Cloud Build status and log URL instead of a bare 404
- Optional connections for a private network path (Serverless VPC connector), a Postgres database,
  a storage bucket, and Firestore — each wires up its own IAM access and environment variables when
  connected
- Separate identities for building and running, each holding only the access its own step needs
- Public access is off by default; the service is only reachable without authentication when
  `public_access` is explicitly turned on
- Publishes a `cloud-run-service` resource
