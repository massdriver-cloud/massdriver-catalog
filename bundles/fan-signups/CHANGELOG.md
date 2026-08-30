# Changelog

## 0.0.0

Initial release.

- Serves the mailing list signups collected at events — email, name, and source — from a `signups`
  table in the app's own schema in the shared PostgreSQL database
- Creates the table and seeds six example signups on the first request, so there is no separate
  migration step
- Accepts a CSV upload that appends rows; a header row is skipped when its first cell reads
  `email`
- Rows are kept as a log of signups rather than a deduplicated list, so the same person signing up
  at two shows stays two rows and the record of where each signup came from survives
- No other app can read this table without an explicit `shared_tables` grant on its own
  `pg-table-set` component, which appears on the canvas as a visible link
- Two-step pipeline: `build` archives `build/app/` and runs it through Cloud Build, `deploy`
  deploys the resulting image to Cloud Run. Both steps derive the same image tag from
  `md_metadata.package.deployment_enqueued_at` rather than passing an output between them
- Separate identities for building and running, each holding only the access its own step needs
- Public access is off by default; the service is only reachable without authentication when
  `public_access` is explicitly turned on
- Publishes a `cloud-run-service` resource
