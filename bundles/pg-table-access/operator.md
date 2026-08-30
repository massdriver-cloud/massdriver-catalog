# pg-table-access runbook

## Deploy fails with `pq: relation "<schema>.<table>" does not exist`

A table on the list is not in the database. Grants are issued against real tables, so this stops
the whole deploy and nothing is created.

Check what is actually there, connected as the administrative user:

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
```

Either the name is wrong, or the app that owns it has not run its migrations in this environment
yet. On a fresh environment it is almost always the second.

## Deploy fails with `pq: schema "<name>" does not exist`

The schema belongs to an app that has not been deployed into this environment at all. Confirm it
is deployed here and not only somewhere else:

```bash
mass instance list tourdates-dev
```

## Deploy fails with `pq: permission denied for table <name>`

The `postgres_cluster` connection is wired to a scoped login rather than the cluster's
administrative one. Only the table's owner or a superuser can grant on it.

Check what is connected on the canvas — the slot needs the `postgres-database` resource published
by `gcp-cloud-sql-postgres`, not a `postgres-table-set` from another app.

## Deploy fails with `dial tcp <ip>:5432: connect: connection timed out`

The provisioner cannot reach the database. Two causes, in order of likelihood.

**The instance has no address reachable from outside the network.** Check
`iac_authorized_networks` on the `gcp-cloud-sql-postgres` component. If it is empty, this bundle
cannot deploy at all — see the caveat in the root README about why that list exists.

**The allowlist is a single address and the provisioner egresses from a pool.** This fails
intermittently: the same configuration succeeds on one attempt and times out on the next, with
nothing different in the logs. Redeploy:

```bash
mass instance deploy artists-dev-access -m "retry" -f
```

Two or three attempts is normal. If it fails five times in a row, it is not this — read the error
again.

## Deploy fails with `pq: role "<name>" already exists`

The role was created by a previous deploy that failed before recording it, or by hand. Terraform
will not adopt an object it did not create.

Add an `import` block to `src/main.tf`, publish, and redeploy — the state lives with the
deployment, so a local `tofu import` has nothing to write to:

```hcl
import {
  to = postgresql_role.login
  id = "reporting"
}
```

```bash
mass bundle publish --development --bundle-directory bundles/pg-table-access
```

```bash
mass instance deploy artists-dev-access -m "adopt existing role" -f
```

Remove the `import` block and publish again once it succeeds.

## The app connects but sees no rows, with no error

The login reached the table and the table is empty, or a `WHERE` clause is filtering everything
out. A missing grant produces `permission denied`, not an empty result — so this is not a
permissions problem.

## Removing a table from a list

The grant is revoked on the next deploy. An app holding an open connection keeps working until it
reconnects, then starts failing on that table. Coordinate with whoever runs the reading app; the
deployment history shows who added the entry and when.

## Confirming what a login can actually reach

The answer to "what can this app see?", and worth running after any change:

```sql
SELECT table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'reporting'
ORDER BY table_schema, table_name, privilege_type;
```

It should match the bundle's `read` and `read_write` lists exactly. More rows than expected means something granted
on a whole schema — find it, because it also covers every table added to that schema in future.

## Decommission

Drops the grants and the role. No data is deleted; the tables belong to other apps.

`DROP ROLE` fails if the role owns any object. This bundle never gives it CREATE, so that should
not happen — if it does, something else granted it in the meantime, and that is worth knowing
about before you remove it.
