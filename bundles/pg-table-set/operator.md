# pg-table-set runbook

## Deploy fails with `dial tcp ... i/o timeout` or `connect: connection refused`

The provisioner cannot reach PostgreSQL.

On Cloud SQL the instance has no public address until somebody adds an entry to
`iac_authorized_networks` on `gcp-cloud-sql-postgres`. Check that bundle's parameters first. If
the list is empty, this bundle can never deploy — it is not a transient failure and retrying
will not help.

If the list is not empty, the address in it is probably not the address the provisioner
actually leaves from. Deploy again and read the connection error: the server logs the source
address of refused connections in Cloud SQL's logs under
`resource.type="cloudsql_database"`.

## Deploy fails with `pq: permission denied to create role`

The `postgres_cluster` dependency is pointing at a login that is not the instance's admin user.
This bundle creates roles and schemas, so it needs the cluster's administrative credential, not
another app's scoped one. Check what is wired into `postgres_cluster` on the canvas.

## Deploy fails with `pq: role "<name>_app" already exists`

A previous deploy created the role and then failed before recording it, or the role was created
by hand. Terraform will not adopt an object it did not create.

Connect as the admin user and either drop the role, or import it:

```
tofu import postgresql_role.app <name>_app
```

Dropping is only safe if nothing owns objects yet. `DROP ROLE` fails while the role owns a
schema or tables, which is the database telling you the app already has data.

## Deploy fails with `pq: relation "<schema>.<table>" does not exist`

A `shared_tables` entry names a table that has not been created yet. Grants are issued against
tables that exist, so the owning app has to run its migrations before the reading app can be
granted access to them.

Order of operations: deploy the owning app, let it create its tables, then deploy the reader.
This bites on a fresh environment where everything is deployed at once for the first time.

## Deploy fails with `pq: schema "<name>" does not exist`

Same cause, one level up: the schema belongs to an app that has not been deployed into this
environment at all. Check that the app named in `shared_tables.schema` really is deployed here
and not only in another environment.

## Changing `app_name`

It is marked immutable, so Massdriver will not let you change it in place. If you genuinely
need to rename, the data has to move by hand: create the new schema, `ALTER TABLE ... SET
SCHEMA`, then decommission the old instance. Nothing in this bundle does that for you.

## Removing a `shared_tables` entry

The grant is revoked on the next deploy. The reading app keeps running with an open connection
until it reconnects, and then starts failing on that table. Coordinate the removal with whoever
owns the reading app — the deployment history shows who added the entry and when.

## Decommission

Dropping the role fails while it still owns the schema and everything in it. Decommission
removes the grants and the role, and the schema goes with it, so **the app's data is deleted**.
Back it up first if it matters:

```
pg_dump --schema=<app_name> ...
```
