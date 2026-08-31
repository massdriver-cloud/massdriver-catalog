# pg-schema

Gives an app its own area inside a shared PostgreSQL database, and a login that reaches
nothing else.

## The problem this solves

One database that many apps share is cheap, easy to back up, and lets apps read each other's
data without copying it around. It also means any app can drop any table.

This bundle splits the difference. Each app gets a schema it owns completely, and a login role
that can do anything inside that schema and nothing outside it. Reading another app's table is
possible, but only by adding it to `shared_tables`, where it shows up on the canvas as a link
between the two apps.

## What gets created

- A login role, `<app_name>_app`, with a generated password. No `CREATEDB`, no `CREATEROLE`,
  not a superuser.
- A schema named after the app, owned by that role. Anything the app creates there belongs to
  it from the start, so no per-table grant is needed for its own data.
- For each entry in `shared_tables`: `USAGE` on the owning app's schema, then `SELECT` (or
  `SELECT`, `INSERT`, `UPDATE`, `DELETE`) on that one table.

## Why schemas and not databases

PostgreSQL cannot grant across databases. Give every app its own database and no app can ever
read another's data without an export job or a replica. Schemas inside one database keep
sharing possible while still giving each app a boundary it owns.

## Answering "can I change this table?"

The list of apps reading a table is a list of `shared_tables` entries pointing at it. That is
visible on the canvas and in the deployment history, so the owning team can see who they will
break before they change anything, and the reading team's dependency is a reviewed change
rather than a line in a migration nobody else saw.

## Requires a SQL connection

Schema creation and table grants cannot be expressed through the Google Cloud API, so this
bundle connects to PostgreSQL directly. On Cloud SQL that means the instance needs an address
the provisioner can reach.

`gcp-cloud-sql-postgres` has an `iac_authorized_networks` parameter for exactly this. Add the
egress address of whatever runs your infrastructure code. The instance stays closed to
everything else, and every connection is still encrypted.

With that list empty the instance has no public address at all, and this bundle cannot run.

## What the app receives

Host, port, database, and the app's own username and password — never the shared cluster's
admin credentials. Plus the schema name, and the list of other apps' tables it was granted.
