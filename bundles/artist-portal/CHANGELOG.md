# Changelog

## 0.0.0

Initial release.

- Serves the artist roster — name, genre, and manager — from an `artists` table in the app's own
  schema in the shared PostgreSQL database
- Creates the table and seeds five example artists on the first request, so there is no separate
  migration step
- Accepts a CSV upload that appends rows; a header row is skipped when its first cell reads `name`
- Two-step pipeline: `build` archives `build/app/` and runs it through Cloud Build, `deploy`
  deploys the resulting image to Cloud Run. Both steps derive the same image tag from
  `md_metadata.package.deployment_enqueued_at` rather than passing an output between them
- Separate identities for building and running, each holding only the access its own step needs
- Public access is off by default; the service is only reachable without authentication when
  `public_access` is explicitly turned on
- Publishes a `cloud-run-service` resource
