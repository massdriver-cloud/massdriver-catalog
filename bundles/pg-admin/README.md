# pg-admin

The real pgAdmin console, connected to the shared database as the administrator.

## What this is for

Every other database bundle in this catalog hands out a *scoped* login — an app gets its own
schema, or a list of tables somebody granted it. This one is the other side of that: the view for
the people who own the database rather than the apps inside it. Every schema, every table, in one
place.

It runs the published `dpage/pgadmin4` image, not a lookalike. What you see is what a DBA already
knows.

## Why it is not public

The connection is the cluster's administrative credential. Anyone who reaches this console and
gets past the sign-in can read every app's data and drop any of it.

`public_access` defaults to off, and Cloud Run then refuses traffic that does not come from inside
the network. Reach it through a proxy instead:

```bash
gcloud run services proxy pg-admin-scp-dev-pgadmin-XXXX \
  --project cory-sandbox-362007 --region us-central1 --port 8080
```

Then open `http://localhost:8080`. Sign in with the email and password set on the component.

Turning `public_access` on puts an administrative console for every citizen app's data on the open
internet behind one password. There is no situation in this platform where that is the right call.

## What it looks like on first sign-in

The server is already in the list, under a group named after the organisation, connected as the
administrative user with the password already supplied. Nothing to configure.

That happens because Cloud Run's disk does not survive a restart. pgAdmin normally keeps its
server list and preferences in a SQLite file, so a restart would lose them — instead a startup
script writes `servers.json` and a `.pgpass` from the connection Massdriver injected, every time
the container boots.

The consequence is worth knowing: **anything you change in the pgAdmin UI is temporary.** Saved
queries, added servers, preference changes — all gone on the next restart. Use it to look at data
and run queries, not as somewhere to keep things.

## One instance, always warm

`min_instance_count` and `max_instance_count` are both hardcoded to 1, and are deliberately not
parameters. pgAdmin's session lives in that same local file, so a second instance would fail
sign-in about half the time, and scaling to zero would sign you out between visits.

This costs one always-running container. That is the price of a stateful application on a platform
built for stateless ones, and it is small.

## Sizing

`medium` is the smallest that works comfortably — 2 CPU and 1 GB. pgAdmin will technically start
on `small`, then spend its time swapping and time out on the first query.

## Useful things to run once you are in

Every schema in the database, which is every citizen app that has been given one:

```sql
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
ORDER BY schema_name;
```

Who can reach what — the answer to the question the platform is built around:

```sql
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee NOT IN ('postgres', 'PUBLIC')
ORDER BY grantee, table_schema, table_name;
```

Each app should appear only against its own schema, apart from grants that were issued on purpose
with `pg-table-access`. Anything else is worth explaining.
