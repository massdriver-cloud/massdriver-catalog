# fan-signups

Collects mailing list signups from events.

## What this is

A starting point, not a finished app. It deploys exactly as it stands and serves a page
showing the database connection it was given, which is the quickest way to confirm the
pipeline works before writing any real code.

Replace everything in `build/app/` with the application. Keep the `PORT` environment
variable — Cloud Run sets it, and the container has to listen on it.

## What it already has

- Its own schema in the shared database, and a login that reaches nothing else
- An image built inside Google Cloud, so nothing needs installing locally
- `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`,
  `DATABASE_PASSWORD` and `DATABASE_SCHEMA` in the environment

## Reading another app's data

Add the table to `shared_tables` on this app's `pg-table-set` component. The team that owns
it can then see that you depend on it, before they change it.
