# Changelog

All notable changes to this bundle are documented here.

## [Unreleased]

### Fixed

- `build/main.tf`: `time_sleep.wait_for_build` had no `triggers`, so it only actually slept on
  an instance's very first deploy — every later deploy reused the already-"complete" resource
  from state and checked Artifact Registry immediately, while the new build was still `QUEUED`.
  Proven in `cap-test`: first deploy completed correctly; the very next redeploy failed with a
  404 after supposedly waiting 480s. Triggers are now keyed on `local.image_tag` (unique per
  deployment) so the wait genuinely happens every time.
- `build/main.tf`: added a `data.http.build_status` read after the wait so a failed
  `verify_image` check reports the real Cloud Build status and log URL instead of a bare 404.

## [0.1.0] - 2026-08-11

### Added

- Initial release. Two-step pipeline: `build` archives `build/app/` and runs it through
  Cloud Build to produce a container image, `deploy` deploys that image to Cloud Run.
- Both steps independently derive the same image tag from
  `md_metadata.package.deployment_enqueued_at` — no output is passed between steps.
- Optional connections for a private network path (Serverless VPC connector), a Postgres
  database, a storage bucket, and Firestore — each auto-wires IAM access and environment
  variables when connected.
- Public access is off by default; a service is only reachable without authentication when
  `public_access` is explicitly turned on.
